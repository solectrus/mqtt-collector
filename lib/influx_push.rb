require 'flux_writer'
require 'forwardable'

class InfluxPush
  extend Forwardable

  def_delegators :config, :logger

  # How long a shutdown waits for the queued batches to reach InfluxDB.
  # It stays below the 10 seconds Docker gives a container before it sends
  # SIGKILL, so the collector can save what is left instead of being killed
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
    @in_flight = []
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :queue, :retry_delay, :shutdown_timeout, :flux_writer

  def ready?
    flux_writer.ready?
  end

  # Wait until InfluxDB is reachable, for up to timeout seconds. The collector
  # starts anyway if it is not: an outage of an external InfluxDB must not stop
  # the collection, because MQTT messages that nobody receives are gone. The
  # queue keeps the records until a write succeeds.
  def wait_until_ready(timeout:)
    logger.info 'Wait until InfluxDB is ready ...'

    started = monotonic_time
    sleep 1 until (ready = ready?) || waited_long_enough?(started, timeout)

    if ready
      logger.info 'InfluxDB is ready.'
    else
      # The outage is already reported, so the first failed write stays silent
      @failing_since = started

      waited = (monotonic_time - started).round
      logger.error "InfluxDB not ready after #{waited} seconds - starting anyway, " \
                   'records are kept in the queue until it is available'
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
    while take_batches.any?
      push(@in_flight)
      @in_flight = []
    end
  end

  # Wait for the pending batches to reach InfluxDB. If they all did, the queue
  # is closed and the run loop ends.
  #
  # The wait is limited, because InfluxDB can still be unreachable - without
  # a limit the retries would keep the process alive until it is killed. The
  # run loop then keeps retrying until the caller ends its thread and saves
  # the unwritten batches.
  def shutdown
    start_shutdown
    wait_for_pending
    queue.close if pending.zero?
  end

  # The batches that did not reach InfluxDB: the ones in the queue, plus the
  # ones the run loop took for its current request. The list is complete only
  # after the thread of the run loop has ended, because it moves batches
  # between both places.
  def unwritten_batches
    batches = @in_flight.dup
    batches << queue.pop(true) until queue.empty?

    # A batch that waits for its retry is in both places. Writing it twice
    # would do no harm, because InfluxDB replaces a point with the same time.
    batches.uniq
  end

  private

  # A ping can block for as long as the HTTP timeout, so the wait counts real
  # seconds. Counting the attempts instead would report 12 seconds for a wait
  # that took minutes.
  def waited_long_enough?(started, timeout)
    timeout && monotonic_time - started >= timeout
  end

  # Takes the batches for the next request from the queue, none once the
  # queue is closed and empty. A shutdown can end this thread at any time, so
  # every batch goes into @in_flight as soon as it leaves the queue. The
  # interrupt waits for the next blocking call: a kill in between would lose a
  # batch that is in neither place.
  def take_batches
    Thread.handle_interrupt(Object => :on_blocking) do
      batch = queue.pop
      @in_flight = [batch].compact
      add_waiting_batches(batch[:records].size) if batch
    end

    @in_flight
  end

  # Adds the batches that go out together with the first one: everything that
  # is queued already, plus everything that arrives within the linger window.
  def add_waiting_batches(records)
    deadline = monotonic_time + LINGER

    while records < MAX_RECORDS_PER_WRITE && (batch = next_batch(deadline))
      @in_flight << batch
      records += batch[:records].size
    end
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
    report_recovery
  rescue StandardError => e
    error_handling(batches, e)
  end

  # Waits before the next attempt. A shutdown ends the wait at once, because
  # sleeping through its whole budget would give the batches no second attempt.
  def wait_before_retry
    return sleep(SHUTDOWN_RETRY_DELAY) if shutting_down?

    @retry_wakeup.pop(timeout: retry_delay)
  end

  def error_handling(batches, error)
    if unacceptable?(error)
      logger.error "Error while pushing to InfluxDB: #{error.message}"
      return refuse(batches)
    end

    report_outage(error)
    requeue(batches)
  end

  # The first failure of an outage is logged with its details. Every retry
  # after it adds a single line, so a glance at the end of the log shows that
  # the collection goes on while InfluxDB is unreachable. The recovery names
  # how long the outage took.
  def report_outage(error)
    if @failing_since
      logger.error "InfluxDB unreachable for #{outage_duration} (#{error.message}) - " \
                   "#{pending} batch(es) waiting, collecting continues"
    else
      @failing_since = monotonic_time
      logger.error "Error while pushing to InfluxDB: #{error.message}"
      logger.error 'Records are kept in the queue and pushed when InfluxDB is available again.'
    end
  end

  def report_recovery
    return unless @failing_since

    logger.info "InfluxDB is available again after #{outage_duration}, #{pending} batch(es) remaining"
    @failing_since = nil
  end

  # An outage can take seconds or days, so the unit follows its length
  def outage_duration
    seconds = (monotonic_time - @failing_since).round
    return "#{seconds}s" if seconds < 60

    minutes, seconds = seconds.divmod(60)
    return "#{minutes}m #{seconds}s" if minutes < 60

    hours, minutes = minutes.divmod(60)
    "#{hours}h #{minutes}m"
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
  # would hold up the whole queue for nothing. The queue is still open,
  # because the shutdown closes it only when no batch is pending.
  def requeue(batches)
    batches.each { |batch| queue << batch }
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
                     "#{pending} batch(es) not written"
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

  def change_pending(delta)
    @mutex.synchronize { @pending += delta }
  end

  # Not affected by a change of the system clock, unlike Time.now
  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
