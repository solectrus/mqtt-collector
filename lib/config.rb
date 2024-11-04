require 'uri'
require 'null_logger'

MAPPING_REGEX = /\AMAPPING_(\d+)_(.+)\z/
MAPPING_TYPES = %w[integer float string boolean].freeze
DEPRECATED_ENV = {
  'MQTT_TOPIC_HOUSE_POW' => %w[house_power integer],
  'MQTT_TOPIC_GRID_POW' => %w[grid_power integer],
  'MQTT_TOPIC_BAT_FUEL_CHARGE' => %w[bat_fuel_charge float],
  'MQTT_TOPIC_BAT_POWER' => %w[bat_power integer],
  'MQTT_TOPIC_CASE_TEMP' => %w[case_temp float],
  'MQTT_TOPIC_CURRENT_STATE' => %w[current_state string],
  'MQTT_TOPIC_MPP1_POWER' => %w[mpp1_power integer],
  'MQTT_TOPIC_MPP2_POWER' => %w[mpp2_power integer],
  'MQTT_TOPIC_MPP3_POWER' => %w[mpp3_power integer],
  'MQTT_TOPIC_INVERTER_POWER' => %w[inverter_power integer],
  'MQTT_TOPIC_POWER_RATIO' => %w[power_ratio integer],
  'MQTT_TOPIC_WALLBOX_CHARGE_POWER' => %w[wallbox_charge_power integer],
  'MQTT_TOPIC_WALLBOX_CHARGE_POWER1' => %w[wallbox_charge_power1 integer],
  'MQTT_TOPIC_WALLBOX_CHARGE_POWER2' => %w[wallbox_charge_power2 integer],
  'MQTT_TOPIC_WALLBOX_CHARGE_POWER3' => %w[wallbox_charge_power3 integer],
  'MQTT_TOPIC_HEATPUMP_POWER' => %w[heatpump_power integer],
}.freeze

class ConfigError < StandardError
  def backtrace
    []
  end
end

class Config
  attr_accessor :mqtt_host,
                :mqtt_port,
                :mqtt_username,
                :mqtt_password,
                :mqtt_ssl,
                :mappings,
                :influx_schema,
                :influx_host,
                :influx_port,
                :influx_token,
                :influx_org,
                :influx_bucket

  def initialize(env, logger: NullLogger.new)
    @logger = logger

    # MQTT Credentials
    @mqtt_host = env.fetch('MQTT_HOST')
    @mqtt_port = env.fetch('MQTT_PORT')
    @mqtt_ssl = env.fetch('MQTT_SSL', 'false') == 'true'
    @mqtt_username = env.fetch('MQTT_USERNAME', nil)
    @mqtt_password = env.fetch('MQTT_PASSWORD', nil)

    # InfluxDB credentials
    @influx_schema = env.fetch('INFLUX_SCHEMA', 'http')
    @influx_host = env.fetch('INFLUX_HOST')
    @influx_port = env.fetch('INFLUX_PORT', '8086')
    @influx_token = env.fetch('INFLUX_TOKEN')
    @influx_org = env.fetch('INFLUX_ORG')
    @influx_bucket = env.fetch('INFLUX_BUCKET')

    # Mappings
    @mappings = mappings_from(env) + deprecated_mappings_from(env)

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

  attr_reader :logger

  private

  def mqtt_schema
    mqtt_ssl ? 'mqtts' : 'mqtt'
  end

  def mappings_from(env)
    mapping_vars = env.select { |key, _| key.match?(MAPPING_REGEX) }

    mapping_groups =
      mapping_vars.group_by { |key, _| key.match(MAPPING_REGEX)[1].to_i }

    mapping_groups
      .transform_values do |values|
        mapping_group = values.first[0].match(MAPPING_REGEX)[1]

        values
          .to_h
          .transform_keys { |key| key.match(MAPPING_REGEX)[2].downcase.to_sym }
          .merge(mapping_group:)
      end
      .values
  end

  def deprecated_mappings_from(env)
    # Start index at the last existing mapping
    index = mappings_from(env).length - 1

    DEPRECATED_ENV.reduce([]) do |mappings, (var, field_and_type)|
      next mappings unless env[var]

      options = deprecated_mapping(env, var, field_and_type)
      deprecation_warning(var, index += 1, options)
      mappings.push(options)
    end
  end

  def deprecated_mapping(env, var, field_and_type)
    options = { topic: env[var] }

    case var
    when 'MQTT_TOPIC_GRID_POW'
      if env['MQTT_FLIP_GRID_POW'] == 'true'
        options[:field_positive] = 'grid_power_minus'
        options[:field_negative] = 'grid_power_plus'
      else
        options[:field_positive] = 'grid_power_plus'
        options[:field_negative] = 'grid_power_minus'
      end
      options[:measurement_positive] = options[
        :measurement_negative
      ] = env.fetch('INFLUX_MEASUREMENT')
    when 'MQTT_TOPIC_BAT_POWER'
      if env['MQTT_FLIP_BAT_POWER'] == 'true'
        options[:field_positive] = 'bat_power_minus'
        options[:field_negative] = 'bat_power_plus'
      else
        options[:field_positive] = 'bat_power_plus'
        options[:field_negative] = 'bat_power_minus'
      end
      options[:measurement_positive] = options[
        :measurement_negative
      ] = env.fetch('INFLUX_MEASUREMENT')
    else
      options[:field] = field_and_type[0]
      options[:measurement] = env.fetch('INFLUX_MEASUREMENT')
    end

    options[:type] = field_and_type[1]
    options
  end

  def deprecation_warning(var, index, options)
    case var
    when 'MQTT_TOPIC_GRID_POW', 'MQTT_TOPIC_BAT_POWER'
      flip_var =
        (
          if var == 'MQTT_TOPIC_GRID_POW'
            'MQTT_FLIP_GRID_POW'
          else
            'MQTT_FLIP_BAT_POWER'
          end
        )

      logger.warn "Variables #{var} and #{flip_var} are deprecated. " \
                    'To remove this warning, please replace the variables by:'
      logger.warn "  MAPPING_#{index}_TOPIC=#{options[:topic]}"
      logger.warn "  MAPPING_#{index}_FIELD_POSITIVE=#{options[:field_positive]}"
      logger.warn "  MAPPING_#{index}_FIELD_NEGATIVE=#{options[:field_negative]}"
      logger.warn "  MAPPING_#{index}_MEASUREMENT_POSITIVE=#{options[:measurement_positive]}"
      logger.warn "  MAPPING_#{index}_MEASUREMENT_NEGATIVE=#{options[:measurement_negative]}"
    else
      logger.warn "Variable #{var} is deprecated. To remove this warning, please replace the variable by:"
      logger.warn "  MAPPING_#{index}_TOPIC=#{options[:topic]}"
      logger.warn "  MAPPING_#{index}_FIELD=#{options[:field]}"
      logger.warn "  MAPPING_#{index}_MEASUREMENT=#{options[:measurement]}"
    end
    logger.warn "  MAPPING_#{index}_TYPE=#{options[:type]}"
    logger.warn ''
  end

  def validate_url!(url)
    URI.parse(url)
  end

  def validate_mappings!
    mappings.each_with_index do |mapping, index|
      validate_mapping!(index, :topic)
      validate_mapping!(index, :type, allow_list: MAPPING_TYPES)

      if mapping[:field_positive] || mapping[:field_negative]
        validate_mapping!(index, :field_positive)
        validate_mapping!(index, :field_negative)
        validate_mapping!(index, :measurement_positive)
        validate_mapping!(index, :measurement_negative)

        validate_mapping!(index, :field, present: false)
        validate_mapping!(index, :measurement, present: false)
      else
        validate_mapping!(index, :field)
        validate_mapping!(index, :measurement)

        validate_mapping!(index, :field_negative, present: false)
        validate_mapping!(index, :field_positive, present: false)
        validate_mapping!(index, :measurement_positive, present: false)
        validate_mapping!(index, :measurement_negative, present: false)
      end
    end
  end

  def validate_mapping!(index, key, present: true, allow_list: nil)
    mapping = mappings[index]
    var = "MAPPING_#{mapping[:mapping_group]}_#{key.upcase}"

    if present
      if mapping[key].nil? || mapping[key].strip == ''
        raise ConfigError, "Missing variable: #{var}"
      end

      if allow_list && !allow_list.include?(mapping[key])
        raise ConfigError,
              "Variable #{var} is invalid: #{mapping[key]}. Must be one of: #{allow_list.join(', ')}"
      end
    elsif mapping[key]
      raise ConfigError, "Unexpected variable: #{var}"
    end
  end
end
