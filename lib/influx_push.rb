require 'flux_writer'
require 'forwardable'

class InfluxPush
  extend Forwardable

  def_delegators :config, :logger

  def initialize(config:, retry_delay: 5)
    @config = config
    @retry_delay = retry_delay
    @queue = Queue.new
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :queue, :retry_delay, :flux_writer

  def ready?
    flux_writer.ready?
  end

  # Hand a batch of records over to be written. The time travels with them,
  # so a write delayed by a retry still lands at the point in time the values
  # were actually received.
  def enqueue(records:, time:)
    queue << { records:, time: }
  end

  # Push batches from the queue to InfluxDB, one at a time, for as long as
  # the queue is open. If InfluxDB is temporarily unreachable, the batch is
  # put back into the queue and retried later instead of being dropped.
  def run
    until queue.closed?
      batch = queue.pop
      push(batch) if batch
    end
  end

  # Wait for the queue to drain, then close it so the run loop can finish
  def shutdown
    until queue.empty?
      logger.info "Waiting for #{queue.size} batch(es) to be pushed to InfluxDB"
      sleep 1
    end

    queue.close
  end

  private

  def push(batch)
    flux_writer.push(batch[:records], time: batch[:time])
    logger.info "Successfully pushed #{batch[:records].size} record(s) " \
                "from #{Time.at(batch[:time])} to InfluxDB"
  rescue StandardError => e
    error_handling(batch, e)

    # Wait a bit before trying again
    sleep(retry_delay)
  end

  def error_handling(batch, error)
    logger.error "Error while pushing to InfluxDB: #{error.message}"

    return if queue.closed?

    # Put the batch back into the queue, to retry later
    queue << batch

    logger.info "The batch has been queued again. Will retry #{queue.size} batch(es) later."
  end
end
