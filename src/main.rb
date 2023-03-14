require 'mqtt'
require 'influxdb-client'

mqtt_client = MQTT::Client.new
mqtt_client.host = '192.168.1.20'
mqtt_client.port = '1888'
mqtt_client.username = 'iobroker'
mqtt_client.password = 'QUHtmE9Hfyf9Aw'
mqtt_client.client_id = 'ruby_client'
mqtt_client.connect
mqtt_client.subscribe('senec/0/ENERGY/GUI_HOUSE_POW')
mqtt_client.subscribe('senec/0/ENERGY/GUI_BAT_DATA_POWER')
mqtt_client.subscribe('senec/0/ENERGY/GUI_GRID_POW')
mqtt_client.subscribe('senec/0/ENERGY/GUI_INVERTER_POWER')
mqtt_client.subscribe('senec/0/ENERGY/STAT_STATE_Text')
mqtt_client.subscribe('0_userdata/0/PV_WB/House_no_wallbox')
mqtt_client.subscribe('0_userdata/0/PV_WB/WB_POWER')
mqtt_client.subscribe('senec/0/ENERGY/STAT_STATE_Text')

mqtt_client.get do |topic, message|
  puts "#{topic}: #{message}"

  InfluxDB2::Client.use('http://192.168.1.30:8086',
                        'zOtqhry06yqKeCtU82D9YWW5IPyMypfKhRNe_xCKUb_F_T6Yu3-uuMgoqhyfqc4xIeGhqTRB_gwz4ozUdaoY4g==',
                        bucket: 'SENEC-TEST',
                        org: 'solectrus',
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
