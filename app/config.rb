require 'uri'

MQTT_TOPICS = %i[
  inverter_power
  mpp1_power
  mpp2_power
  mpp3_power
  house_pow
  bat_fuel_charge
  wallbox_charge_power
  wallbox_charge_power0
  wallbox_charge_power1
  wallbox_charge_power2
  wallbox_charge_power3
  bat_power
  grid_pow
  power_ratio
  current_state
  current_state_code
  current_state_ok
  application_version
  case_temp
  bat_charge_current
  bat_voltage
].freeze

Config =
  Struct.new(
    # MQTT credentials
    :mqtt_host,
    :mqtt_port,
    :mqtt_username,
    :mqtt_password,
    :mqtt_ssl,
    # MQTT topics
    :mqtt_topic_inverter_power,
    :mqtt_topic_mpp1_power,
    :mqtt_topic_mpp2_power,
    :mqtt_topic_mpp3_power,
    :mqtt_topic_house_pow,
    :mqtt_topic_bat_fuel_charge,
    :mqtt_topic_wallbox_charge_power,
    :mqtt_topic_wallbox_charge_power0,
    :mqtt_topic_wallbox_charge_power1,
    :mqtt_topic_wallbox_charge_power2,
    :mqtt_topic_wallbox_charge_power3,
    :mqtt_topic_bat_power,
    :mqtt_topic_grid_pow,
    :mqtt_topic_power_ratio,
    :mqtt_topic_current_state,
    :mqtt_topic_current_state_code,
    :mqtt_topic_current_state_ok,
    :mqtt_topic_application_version,
    :mqtt_topic_case_temp,
    :mqtt_topic_bat_charge_current,
    :mqtt_topic_bat_voltage,
    # MQTT options
    :mqtt_flip_bat_power,
    # InfluxDB credentials
    :influx_schema,
    :influx_host,
    :influx_port,
    :influx_token,
    :influx_org,
    :influx_bucket,
    :influx_measurement,
    keyword_init: true,
  ) do
    def self.from_env(options = {})
      new(
        {}.merge(mqtt_credentials_from_env)
          .merge(mqtt_topics_from_env)
          .merge(mqtt_options_from_env)
          .merge(influx_credentials_from_env)
          .merge(options),
      )
    end

    def self.mqtt_credentials_from_env
      {
        mqtt_host: ENV.fetch('MQTT_HOST'),
        mqtt_port: ENV.fetch('MQTT_PORT'),
        mqtt_ssl: ENV.fetch('MQTT_SSL', 'false') == 'true',
        mqtt_username: ENV.fetch('MQTT_USERNAME'),
        mqtt_password: ENV.fetch('MQTT_PASSWORD'),
      }
    end

    def self.mqtt_topics_from_env
      MQTT_TOPICS.each_with_object({}) do |topic, hash|
        value = ENV.fetch("MQTT_TOPIC_#{topic.to_s.upcase}", nil)
        next unless value

        hash["mqtt_topic_#{topic}"] = value
      end
    end

    def self.mqtt_options_from_env
      { mqtt_flip_bat_power: ENV.fetch('MQTT_FLIP_BAT_POWER', nil) == 'true' }
    end

    def self.influx_credentials_from_env
      {
        influx_host: ENV.fetch('INFLUX_HOST'),
        influx_schema: ENV.fetch('INFLUX_SCHEMA', 'http'),
        influx_port: ENV.fetch('INFLUX_PORT', '8086'),
        influx_token: ENV.fetch('INFLUX_TOKEN'),
        influx_org: ENV.fetch('INFLUX_ORG'),
        influx_bucket: ENV.fetch('INFLUX_BUCKET'),
        influx_measurement: ENV.fetch('INFLUX_MEASUREMENT'),
      }
    end

    def initialize(*options)
      super

      validate_url!(influx_url)
      validate_url!(mqtt_url)
    end

    def influx_url
      "#{influx_schema}://#{influx_host}:#{influx_port}"
    end

    def mqtt_url
      "#{mqtt_schema}://#{mqtt_host}:#{mqtt_port}"
    end

    private

    def mqtt_schema
      mqtt_ssl ? 'mqtts' : 'mqtt'
    end

    def validate_url!(url)
      URI.parse(url)
    end
  end
