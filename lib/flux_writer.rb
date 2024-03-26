require 'influxdb-client'

class FluxWriter
  def initialize(config)
    @config = config
  end

  attr_reader :config

  def push(records, time:)
    write_api.write(
      data: points(records, time:),
      bucket: config.influx_bucket,
      org: config.influx_org,
    )
  end

  private

  def points(records, time:)
    records.map do |record|
      InfluxDB2::Point.new(
        time:,
        name: record[:measurement],
        fields: { record[:field] => record[:value] },
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
