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

  def initialize(config:, retry_delay: 5, shutdown_timeout: DEFAULT_SHUTDOWN_TIMEOUT)
    @config = config
    @retry_delay = retry_delay
    @shutdown_timeout = shutdown_timeout
    @queue = Queue.new
    @mutex = Mutex.new
    @pending = 0
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :queue, :retry_delay, :shutdown_timeout, :flux_writer

  def ready?
    flux_writer.ready?
  end

  # Hand a batch of records over to be written. The time travels with them,
  # so a write delayed by a retry still lands at the point in time the values
  # were actually received.
  def enqueue(records:, time:)
    # The counter and the queue have to change together. A shutdown kills the
    # thread that calls this, and a kill between the two steps would leave a
    # batch counted but not queued. The count would never reach zero again.
    Thread.handle_interrupt(Object => :never) do
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
    wait_for_pending
    give_up
    queue.close
  end

  private

  def push(batch)
    flux_writer.push(batch[:records], time: batch[:time])
    change_pending(-1)
    logger.info "Successfully pushed #{batch[:records].size} record(s) " \
                "from #{Time.at(batch[:time])} to InfluxDB"
  rescue StandardError => e
    error_handling(batch, e)

    # Wait a bit before trying again
    sleep(retry_delay) unless giving_up?
  end

  def error_handling(batch, error)
    logger.error "Error while pushing to InfluxDB: #{error.message}"

    # After the shutdown gave up, a retry can never reach InfluxDB. The
    # shutdown already named how many batches are lost, so the batch is only
    # counted out here.
    return change_pending(-1) if giving_up?

    # Put the batch back into the queue, to retry later
    queue << batch

    logger.info "The batch has been queued again. Will retry #{pending} batch(es) later."
  rescue ClosedQueueError
    # The shutdown closed the queue while this batch was being written
    logger.error "Dropping #{batch[:records].size} record(s) " \
                 "from #{Time.at(batch[:time])} - they were never written to InfluxDB"
    change_pending(-1)
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
