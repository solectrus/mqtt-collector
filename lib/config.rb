require 'uri'
require 'null_logger'

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
  current_state_ok
  case_temp
  heatpump_power
].freeze

DEPRECATED_ENV = {
  'MQTT_TOPIC_HOUSE_POWER' => 'house_power',
  'MQTT_TOPIC_GRID_POW' => 'grid_power',
  'MQTT_TOPIC_BAT_FUEL_CHARGE' => 'bat_fuel_charge',
  'MQTT_TOPIC_BAT_POWER' => 'bat_power',
  'MQTT_TOPIC_CASE_TEMP' => 'case_temp',
  'MQTT_TOPIC_CURRENT_STATE' => 'current_state',
  'MQTT_TOPIC_MPP1_POWER' => 'mpp1_power',
  'MQTT_TOPIC_MPP2_POWER' => 'mpp2_power',
  'MQTT_TOPIC_MPP3_POWER' => 'mpp3_power',
  'MQTT_TOPIC_INVERTER_POWER' => 'inverter_power',
  'MQTT_TOPIC_WALLBOX_CHARGE_POWER' => 'wallbox_charge_power',
  'MQTT_TOPIC_HEATPUMP_POWER' => 'heatpump_power',
}.freeze

MAPPING_REGEX = /^MAPPING_(\d+)_(.+)/

Config =
  Struct.new(
    # MQTT credentials
    :mqtt_host,
    :mqtt_port,
    :mqtt_username,
    :mqtt_password,
    :mqtt_ssl,
    # Mappings
    :mappings,
    # InfluxDB credentials
    :influx_schema,
    :influx_host,
    :influx_port,
    :influx_token,
    :influx_org,
    :influx_bucket,
    keyword_init: true,
  ) do
    def self.from(env)
      new(
        {}.merge(mqtt_credentials_from(env))
          .merge(mappings_from(env))
          .merge(influx_credentials_from(env)),
      )
    end

    def self.mqtt_credentials_from(env)
      {
        mqtt_host: env.fetch('MQTT_HOST'),
        mqtt_port: env.fetch('MQTT_PORT'),
        mqtt_ssl: env.fetch('MQTT_SSL', 'false') == 'true',
        mqtt_username: env.fetch('MQTT_USERNAME'),
        mqtt_password: env.fetch('MQTT_PASSWORD'),
      }
    end

    def self.mappings_from(env)
      # Select all key/value that match the regex
      mapping_vars = env.select do |key, _|
        key.match?(MAPPING_REGEX)
      end

      # Group by the number in the key
      mapping_groups = mapping_vars.group_by do |key, _|
        key.match(MAPPING_REGEX)[1].to_i
      end

      # Transform the groups into an array, example:
      #   [
      #     {
      #       topic: 'senec/0/ENERGY/GUI_INVERTER_POWER',
      #       measurement: 'PV',
      #       field: 'inverter_power'
      #     },
      #     { ...
      # }
      mappings = mapping_groups.transform_values do |values|
        values.to_h.transform_keys do |key|
          key.match(MAPPING_REGEX)[2].downcase.to_sym
        end
      end.values + deprecated_mappings(env)

      { mappings: }
    end

    def self.deprecated_mappings(env)
      mappings = []

      DEPRECATED_ENV.each_pair do |topic, field|
        next unless env[topic]

        options = {}
        options[:topic] = env[topic]

        case topic
        when 'MQTT_TOPIC_GRID_POW'
          if env['MQTT_FLIP_GRID_POW'] == 'true'
            options[:field_positive] = 'grid_power_minus'
            options[:field_negative] = 'grid_power_plus'
          else
            options[:field_positive] = 'grid_power_plus'
            options[:field_negative] = 'grid_power_minus'
          end
          options[:measurement_positive] = env['INFLUX_MEASUREMENT']
          options[:measurement_negative] = env['INFLUX_MEASUREMENT']
        when 'MQTT_TOPIC_BAT_POWER'
          if env['MQTT_FLIP_BAT_POWER'] == 'true'
            options[:field_positive] = 'bat_power_minus'
            options[:field_negative] = 'bat_power_plus'
          else
            options[:field_positive] = 'bat_power_plus'
            options[:field_negative] = 'bat_power_minus'
          end
          options[:measurement_positive] = env['INFLUX_MEASUREMENT']
          options[:measurement_negative] = env['INFLUX_MEASUREMENT']
        else
          options[:field] = field
          options[:measurement] = env['INFLUX_MEASUREMENT']
        end

        mappings.push(options)
      end

      mappings
    end

    def self.influx_credentials_from(env)
      {
        influx_host: env.fetch('INFLUX_HOST'),
        influx_schema: env.fetch('INFLUX_SCHEMA', 'http'),
        influx_port: env.fetch('INFLUX_PORT', '8086'),
        influx_token: env.fetch('INFLUX_TOKEN'),
        influx_org: env.fetch('INFLUX_ORG'),
        influx_bucket: env.fetch('INFLUX_BUCKET'),
      }
    end

    def initialize(*options)
      super

      validate_url!(influx_url)
      validate_url!(mqtt_url)
      validate_mappings!
    end

    def influx_url
      "#{influx_schema}://#{influx_host}:#{influx_port}"
    end

    def mqtt_url
      "#{mqtt_schema}://#{mqtt_host}:#{mqtt_port}"
    end

    attr_writer :logger

    def logger
      @logger ||= NullLogger.new
    end

    private

    def mqtt_schema
      mqtt_ssl ? 'mqtts' : 'mqtt'
    end

    def validate_url!(url)
      URI.parse(url)
    end

    def validate_mappings!
      mappings.each do |value|
        next if (value.keys & %i[topic measurement field]).size == 3
        next if (value.keys & %i[topic measurement_positive measurement_negative field_positive field_negative]).size == 5

        raise ArgumentError, "Missing required keys: #{value.keys}"
      end
    end
  end
