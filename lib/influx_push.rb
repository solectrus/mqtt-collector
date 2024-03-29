require 'flux_writer'
require 'forwardable'

class InfluxPush
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:)
    @config = config
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :flux_writer

  def call(record, time:)
    flux_writer.push(record, time:)
  rescue StandardError => e
    logger.error "Error while pushing to InfluxDB: #{e.message}"

    # Wait a bit before trying again
    sleep(5)

    retry
  end
end
