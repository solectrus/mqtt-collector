#!/usr/bin/env ruby

require 'dotenv/load'
require 'mqtt'
require 'influxdb-client'

# Hash to map MQTT topic to InfluxDB topic name
config = {}
config[ENV['MQTT_TOPIC_HOUSE_POW']] = 'house_power'
config[ENV['MQTT_TOPIC_BAT_CHARGE_CURRENT']] = 'bat_charge_current'
config[ENV['MQTT_TOPIC_BAT_FUEL_CHARGE']] = 'bat_fuel_charge'
config[ENV['MQTT_TOPIC_BAT_POWER']] = ''
config[ENV['MQTT_TOPIC_BAT_VOLTAGE']] = 'bat_voltage'
config[ENV['MQTT_TOPIC_CASE_TEMP']] = 'case_temp'
config[ENV['MQTT_TOPIC_CURRENT_STATE']] = 'current_state'
config[ENV['MQTT_TOPIC_GRID_POW']] = ''
config[ENV['MQTT_TOPIC_INVERTER_POWER']] = 'inverter_power'
config[ENV['MQTT_TOPIC_WALLBOX_CHARGE_POWER']] = 'wallbox_charge_power'

flipPosNegPwrGrid = (ENV['FLIP_POS_NEG_PWR_GRID'] == 'true')
flipPosNegPwrBatt = (ENV['FLIP_POS_NEG_PWR_BATT'] == 'true')

absValueOnly= (ENV['ABS_VALUE_ONLY'] == 'true')

puts "flipPosNegPwrGrid: #{flipPosNegPwrGrid}"
puts "flipPosNegPwrBatt: #{flipPosNegPwrBatt}"
puts "absValueOnly: #{absValueOnly}"

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
mqtt_client.subscribe(ENV['MQTT_TOPIC_GRID_POW'])
mqtt_client.subscribe(ENV['MQTT_TOPIC_BAT_CHARGE_CURRENT'])
mqtt_client.subscribe(ENV['MQTT_TOPIC_BAT_FUEL_CHARGE'])
mqtt_client.subscribe(ENV['MQTT_TOPIC_BAT_POWER'])
mqtt_client.subscribe(ENV['MQTT_TOPIC_BAT_VOLTAGE'])
mqtt_client.subscribe(ENV['MQTT_TOPIC_CASE_TEMP'])
mqtt_client.subscribe(ENV['MQTT_TOPIC_CURRENT_STATE'])
mqtt_client.subscribe(ENV['MQTT_TOPIC_INVERTER_POWER'])
mqtt_client.subscribe(ENV['MQTT_TOPIC_WALLBOX_CHARGE_POWER'])

# Start MQTT Client
mqtt_client.get do |topic, message|
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

    # convert MQTT topic name to influx name
    topic_name = config[topic]

    value = message.to_i
    isPos = value.positive?

    # check whether to use positive or negative value for BAT_POWER
    if topic == ENV['MQTT_TOPIC_BAT_POWER']
      topic_name = if (isPos && !flipPosNegPwrBatt)
                     'bat_power_plus'
                   else
                     'bat_power_minus'
                   end
    end

    # check whether to use positive or negative value for GRID_POWER
    if topic == ENV['MQTT_TOPIC_GRID_POW']
      topic_name = if (isPos && !flipPosNegPwrGrid)
                     'grid_power_plus'
                   else
                     'grid_power_minus'
                   end
    end

    if absValueOnly 
    value = isPos ? value : -value
    end
    puts "#{topic_name}: #{value}"

    point = InfluxDB2::Point.new(name: 'SENEC')
                            .add_field(topic_name, value)

    write_api.write(data: point)
  end
end

mqtt_client.disconnect
