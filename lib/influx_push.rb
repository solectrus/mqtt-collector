require 'flux_writer'
require 'forwardable'

class InfluxPush
  extend Forwardable

  def_delegators :config, :logger

  # How long a shutdown waits for the queued batches to reach InfluxDB.
  # It stays below the 10 seconds Docker gives a container before it sends
  # SIGKILL, so the collector can report what it lost instead of being killed
  # in the middle of the wait.
  DEFAULT_SHUTDOWN_TIMEOUT = 5

  # How long a retry waits while the collector shuts down. It is short, so the
  # pending batches get more than one attempt inside the shutdown budget.
  SHUTDOWN_RETRY_DELAY = 0.5

  # InfluxDB refuses the data itself with these codes: the line protocol is
  # broken (400), or a field does not match the type it already has (422). A
  # retry sends the same data again, so such a batch would circle in the queue
  # for as long as the collector runs.
  UNACCEPTABLE_HTTP_CODES = %w[400 422].freeze

  # The queue only lives in memory, so it cannot grow without a limit. A long
  # outage would fill the memory until the container is killed, which loses
  # the whole queue instead of its oldest part. At one message per second this
  # holds more than a day.
  MAX_QUEUE_SIZE = 100_000

  # How many records one request to InfluxDB can carry. Without a limit, the
  # queue of a long outage would go out as a single huge request, which can
  # exceed what InfluxDB accepts. The InfluxDB documentation recommends 5000
  # points per write.
  MAX_RECORDS_PER_WRITE = 5_000

  # How many seconds a write waits for more messages before it goes out. A
  # broker sends the topics of one reading in the same moment, but a fast
  # InfluxDB answers before the second message is even converted - so without
  # this window every message gets its own request. The wait costs no accuracy,
  # because every record keeps the time it arrived. It only happens when the
  # queue runs empty, so a backlog still goes out at full speed.
  LINGER = 1

  def initialize(config:, retry_delay: 5, shutdown_timeout: DEFAULT_SHUTDOWN_TIMEOUT)
    @config = config
    @retry_delay = retry_delay
    @shutdown_timeout = shutdown_timeout
    @queue = Queue.new
    @retry_wakeup = Queue.new
    @mutex = Mutex.new
    @pending = 0
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :queue, :retry_delay, :shutdown_timeout, :flux_writer

  def ready?
    flux_writer.ready?
  end

  # Wait until InfluxDB is reachable, for up to timeout seconds, and report
  # whether it is - the collector has nothing to do without InfluxDB. The name
  # says that this waits, which a question mark would hide.
  def wait_until_ready(timeout:) # rubocop:disable Naming/PredicateMethod
    logger.info 'Wait until InfluxDB is ready ...'

    started = monotonic_time
    sleep 1 until (ready = ready?) || waited_long_enough?(started, timeout)

    if ready
      logger.info 'InfluxDB is ready.'
      true
    else
      waited = (monotonic_time - started).round
      logger.error "InfluxDB not ready after #{waited} seconds - aborting."
      false
    end
  end

  # Hand a batch of records over to be written. The time travels with them,
  # so a write delayed by a retry still lands at the point in time the values
  # were actually received.
  def enqueue(records:, time:)
    # The counter and the queue have to change together. A shutdown kills the
    # thread that calls this, and a kill between the two steps would leave a
    # batch counted but not queued. The count would never reach zero again.
    Thread.handle_interrupt(Object => :never) do
      drop_oldest if queue.size >= MAX_QUEUE_SIZE
      change_pending(+1)
      queue << { records:, time: }
    end
  end

  # How many batches have not reached InfluxDB yet: the ones waiting plus the
  # one being written right now. A batch that goes back into the queue after a
  # failed write stays counted, so this never reports progress that a retry
  # can take back.
  def pending
    @mutex.synchronize { @pending }
  end

  # Push batches to InfluxDB until the queue is closed and empty. Every batch
  # that already waits goes out together with the first one, so the messages
  # that arrive in the same second cost one request instead of one each. If
  # InfluxDB is temporarily unreachable, the batches are put back into the
  # queue and retried later instead of being dropped.
  def run
    while (batch = queue.pop)
      push([batch, *waiting_batches(batch[:records].size)])
    end
  end

  # Wait for the pending batches to reach InfluxDB, then stop the run loop.
  #
  # The wait is limited, because InfluxDB can still be unreachable - without
  # a limit the retries would keep the process alive until it is killed, and
  # the queue would be lost anyway. Whatever is left over is named in the log
  # instead of disappearing silently.
  def shutdown
    start_shutdown
    wait_for_pending
    give_up
    queue.close
  end

  private

  # A ping can block for as long as the HTTP timeout, so the wait counts real
  # seconds. Counting the attempts instead would report 12 seconds for a wait
  # that took minutes.
  def waited_long_enough?(started, timeout)
    timeout && monotonic_time - started >= timeout
  end

  # Collects the batches that go out together with the one the run loop holds:
  # everything that is queued already, plus everything that arrives within the
  # linger window.
  def waiting_batches(records)
    batches = []
    deadline = monotonic_time + LINGER

    while records < MAX_RECORDS_PER_WRITE && (batch = next_batch(deadline))
      batches << batch
      records += batch[:records].size
    end

    batches
  end

  # Takes the next batch, waiting for it until the window is over. A timeout of
  # zero only takes what is there, which is what a shutdown needs: the batches
  # in hand are the ones it waits for.
  def next_batch(deadline)
    remaining = shutting_down? ? 0 : deadline - monotonic_time

    queue.pop(timeout: [remaining, 0].max)
  end

  def push(batches)
    flux_writer.push(batches)
    change_pending(-batches.size)
    logger.info "Successfully pushed #{describe(batches)} to InfluxDB"
  rescue StandardError => e
    error_handling(batches, e)
  end

  # Waits before the next attempt. A shutdown ends the wait at once, because
  # sleeping through its whole budget would lose the batches it waits for.
  def wait_before_retry
    return sleep(SHUTDOWN_RETRY_DELAY) if shutting_down?

    @retry_wakeup.pop(timeout: retry_delay)
  end

  def error_handling(batches, error)
    logger.error "Error while pushing to InfluxDB: #{error.message}"

    # After the shutdown gave up, a retry can never reach InfluxDB. The
    # shutdown already named how many batches are lost, so the batches are
    # only counted out here.
    return change_pending(-batches.size) if giving_up?
    return refuse(batches) if unacceptable?(error)

    requeue(batches)
  end

  # InfluxDB refuses one request for a single broken record, so a request that
  # carries several batches can fail for one of them alone. Writing them one by
  # one keeps the good ones and drops only the batch that is really refused.
  def refuse(batches)
    unless batches.one?
      logger.warn "InfluxDB refused #{describe(batches)} - writing them one by one"
      return batches.each { |batch| push([batch]) }
    end

    logger.error "InfluxDB refused #{describe(batches)} - a retry sends the same data, " \
                 'so the batch is dropped'
    change_pending(-1)
  end

  # Puts the batches back into the queue, to retry them later. Only batches
  # that wait for another attempt get a pause. A pause after a dropped batch
  # would hold up the whole queue for nothing.
  def requeue(batches)
    batches.each_with_index do |batch, index|
      queue << batch
    rescue ClosedQueueError
      # The shutdown closed the queue while these batches were being written.
      # Whatever did not get back into it can never be written.
      lost = batches.drop(index)
      logger.error "Dropping #{describe(lost)} - they were never written to InfluxDB"
      return change_pending(-lost.size)
    end

    logger.info "Queued #{batches.size} batch(es) again. Will retry #{pending} batch(es) later."
    wait_before_retry
  end

  # Names a request in a log line. It only counts what went into it: the push
  # runs in its own thread, so the line does not follow the messages it belongs
  # to - and those are already in the log, with their topics and their values.
  def describe(batches)
    "#{batches.sum { |batch| batch[:records].size }} record(s) " \
      "from #{batches.size} message(s)"
  end

  # Keeps the newest data, because a dashboard shows the recent values first
  def drop_oldest
    queue.pop(true)
    change_pending(-1)
    warn_about_limit
  rescue ThreadError
    # The push thread took the batch first, so there is room again
    nil
  end

  def warn_about_limit
    return if @limit_reached

    @limit_reached = true
    logger.warn "The queue holds #{MAX_QUEUE_SIZE} batches, which is the limit. " \
                'From now on the oldest batch is dropped for every new one.'
  end

  def unacceptable?(error)
    error.is_a?(InfluxDB2::InfluxError) && UNACCEPTABLE_HTTP_CODES.include?(error.code)
  end

  def wait_for_pending
    deadline = monotonic_time + shutdown_timeout

    while pending.positive?
      if monotonic_time >= deadline
        logger.error "InfluxDB is still unreachable after #{shutdown_timeout} seconds - " \
                     "giving up on #{pending} batch(es)"
        return
      end

      logger.info "Waiting for #{pending} batch(es) to be pushed to InfluxDB"
      sleep 1
    end
  end

  # Wakes a retry that waits out its delay, so the pending batches are tried
  # again right away instead of at the end of the shutdown
  def start_shutdown
    @mutex.synchronize { @shutting_down = true }
    @retry_wakeup.close
  end

  def shutting_down?
    @mutex.synchronize { @shutting_down }
  end

  # From here on a failed write is not retried anymore, so the run loop can
  # finish instead of putting the batch back into a queue nobody drains.
  def give_up
    @mutex.synchronize { @giving_up = true }
  end

  def giving_up?
    @mutex.synchronize { @giving_up }
  end

  def change_pending(delta)
    @mutex.synchronize { @pending += delta }
  end

  # Not affected by a change of the system clock, unlike Time.now
  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
