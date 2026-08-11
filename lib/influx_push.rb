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
  # were actually received. The topic travels with them as well, because two
  # messages can carry the same number of records at the same second - only
  # the topic tells their log lines apart.
  def enqueue(records:, time:, topic:)
    # The counter and the queue have to change together. A shutdown kills the
    # thread that calls this, and a kill between the two steps would leave a
    # batch counted but not queued. The count would never reach zero again.
    Thread.handle_interrupt(Object => :never) do
      drop_oldest if queue.size >= MAX_QUEUE_SIZE
      change_pending(+1)
      queue << { records:, time:, topic: }
    end
  end

  # How many batches have not reached InfluxDB yet: the ones waiting plus the
  # one being written right now. A batch that goes back into the queue after a
  # failed write stays counted, so this never reports progress that a retry
  # can take back.
  def pending
    @mutex.synchronize { @pending }
  end

  # Push batches to InfluxDB, one at a time, until the queue is closed and
  # empty. If InfluxDB is temporarily unreachable, the batch is put back into
  # the queue and retried later instead of being dropped.
  def run
    while (batch = queue.pop)
      push(batch)
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

  def push(batch)
    flux_writer.push(batch[:records], time: batch[:time])
    change_pending(-1)
    logger.info "Successfully pushed #{describe(batch)} to InfluxDB"
  rescue StandardError => e
    # Only a batch that waits for another attempt needs a pause. A pause after
    # a dropped batch would hold up the whole queue for nothing.
    wait_before_retry if error_handling(batch, e)
  end

  # Waits before the next attempt. A shutdown ends the wait at once, because
  # sleeping through its whole budget would lose the batches it waits for.
  def wait_before_retry
    return sleep(SHUTDOWN_RETRY_DELAY) if shutting_down?

    @retry_wakeup.pop(timeout: retry_delay)
  end

  def error_handling(batch, error)
    logger.error "Error while pushing to InfluxDB: #{error.message}"

    # After the shutdown gave up, a retry can never reach InfluxDB. The
    # shutdown already named how many batches are lost, so the batch is only
    # counted out here.
    if giving_up?
      change_pending(-1)
      return false
    end

    if unacceptable?(error)
      logger.error "InfluxDB refused #{describe(batch)} - a retry sends the same data, " \
                   'so the batch is dropped'
      change_pending(-1)
      return false
    end

    # Put the batch back into the queue, to retry later
    queue << batch

    logger.info "The batch has been queued again. Will retry #{pending} batch(es) later."
    true
  rescue ClosedQueueError
    # The shutdown closed the queue while this batch was being written
    logger.error "Dropping #{describe(batch)} - they were never written to InfluxDB"
    change_pending(-1)
    false
  end

  # Names a batch in a log line. The push runs in its own thread, so the line
  # does not follow the message it belongs to. The topic and the time say
  # which message it is.
  def describe(batch)
    "#{batch[:records].size} record(s) from #{batch[:topic]} at #{Time.at(batch[:time])}"
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
