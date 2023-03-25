require 'dotenv/load'
require 'mqtt'
require 'influxdb-client'

# Create MQTT Client
mqtt_client = MQTT::Client.new
mqtt_client.host = ENV['MQTT_HOST']
mqtt_client.port = ENV['MQTT_PORT']
mqtt_client.username = ENV['MQTT_USER']
mqtt_client.password = ENV['MQTT_PASSWORD']
mqtt_client.client_id = ENV['MQTT_CLIENTID']
mqtt_client.connect

# Subscribe to the MQTT Topics
mqtt_client.subscribe(ENV['MQTT_TOPIC_HOUSE_POW'])
mqtt_client.subscribe('senec/0/ENERGY/GUI_BAT_DATA_POWER')
mqtt_client.subscribe('senec/0/ENERGY/GUI_GRID_POW')
mqtt_client.subscribe('senec/0/ENERGY/GUI_INVERTER_POWER')
mqtt_client.subscribe('senec/0/ENERGY/STAT_STATE_Text')
mqtt_client.subscribe('0_userdata/0/PV_WB/House_no_wallbox')
mqtt_client.subscribe('0_userdata/0/PV_WB/WB_POWER')
mqtt_client.subscribe('senec/0/ENERGY/STAT_STATE_Text')

# Start MQTT Client
mqtt_client.get do |topic, message|
  puts "#{topic}: #{message}"

  InfluxDB2::Client.use(ENV['INFLUX_HOST'],
                        ENV['INFLUX_TOKEN'],
                        bucket: ENV['INFLUX_BUCKET'],
                        org: ENV['INFLUX_ORG'],
                        precision: InfluxDB2::WritePrecision::SECOND,
                        use_ssl: false) do |influx_client|
    write_options = InfluxDB2::WriteOptions.new(write_type: InfluxDB2::WriteType::BATCHING,
                                                batch_size: 10, flush_interval: 5_000,
                                                max_retries: 3, max_retry_delay: 15_000)
    write_api = influx_client.create_write_api(write_options:)
    point = InfluxDB2::Point.new(name: 'SENEC')
                            .add_field(topic, message.to_i)

    write_api.write(data: point)
  end
end

mqtt_client.disconnect
