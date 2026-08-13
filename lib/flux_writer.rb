require 'influxdb-client'

class FluxWriter
  def initialize(config)
    @config = config
  end

  attr_reader :config

  def ready?
    influx_client.ping.status == 'ok'
  end

  # Writes batches of records in a single request. Every batch keeps its own
  # time, so a batch does not move to the time of the batch next to it.
  def push(batches)
    write_api.write(
      data: points(batches),
      bucket: config.influx_bucket,
      org: config.influx_org,
    )
  end

  private

  def points(batches)
    batches.flat_map { |batch| points_for(batch[:records], batch[:time]) }
  end

  def points_for(records, time)
    records.map do |record|
      InfluxDB2::Point.new(
        time:,
        name: record[:measurement],
        fields: {
          record[:field] => record[:value],
        },
      )
    end
  end

  def influx_client
    @influx_client ||=
      InfluxDB2::Client.new(
        config.influx_url,
        config.influx_token,
        use_ssl: config.influx_schema == 'https',
        precision: InfluxDB2::WritePrecision::SECOND,
      )
  end

  def write_api
    @write_api ||= influx_client.create_write_api
  end
end
