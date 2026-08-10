require 'uri'
require 'null_logger'

MAPPING_REGEX = /\AMAPPING_(\d+)_(.+)\z/
MAPPING_TYPES = %w[integer float string boolean].freeze
# Evaluator replaces every non-alphanumeric character of a formula variable
# by an underscore and downcases it. Names that differ in those characters
# only (my-power and my_power, or Washer and washer) would become the same
# variable and silently return a wrong value, so a name is restricted to what
# survives that step unchanged.
MAPPING_NAME_REGEX = /\A[a-z_][a-z0-9_]*\z/
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

class Config
  class Error < StandardError
    def backtrace = []
  end

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
          .reject { |_key, value| blank?(value) }
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
      if virtual_mapping?(mapping)
        validate_mapping!(mapping, :formula)
        validate_mapping!(mapping, :json_key, present: false)
        validate_mapping!(mapping, :json_path, present: false)
        validate_mapping!(mapping, :json_formula, present: false)
      else
        validate_mapping!(mapping, :topic)
      end

      validate_mapping!(mapping, :type, allow_list: MAPPING_TYPES)

      if mapping[:null_to_zero]
        validate_mapping!(mapping, :null_to_zero, allow_list: %w[true false])
      end

      validate_name!(mapping, index)
      validate_max_age!(mapping)
      validate_destination!(mapping)
    end
  end

  def validate_max_age!(mapping)
    max_age = mapping[:max_age]
    return unless max_age

    unless mapping[:name]
      raise Config::Error,
            "Variable #{mapping_var(mapping, :max_age)} requires #{mapping_var(mapping, :name)} to be set"
    end

    return if max_age.match?(/\A\d+\z/) && max_age.to_i.positive?

    invalid!(mapping, :max_age, "#{max_age}. Must be a positive number of seconds")
  end

  def validate_destination!(mapping)
    if mapping[:field_positive] || mapping[:field_negative]
      validate_mapping!(mapping, :field_positive)
      validate_mapping!(mapping, :field_negative)
      validate_mapping!(mapping, :measurement_positive)
      validate_mapping!(mapping, :measurement_negative)

      validate_mapping!(mapping, :field, present: false)
      validate_mapping!(mapping, :measurement, present: false)
    else
      validate_mapping!(mapping, :field)
      validate_mapping!(mapping, :measurement)

      validate_mapping!(mapping, :field_negative, present: false)
      validate_mapping!(mapping, :field_positive, present: false)
      validate_mapping!(mapping, :measurement_positive, present: false)
      validate_mapping!(mapping, :measurement_negative, present: false)
    end
  end

  # A mapping without a topic computes its value from other mappings. Blank
  # variables are dropped while reading the ENV, so a topic set to an empty
  # string arrives here as nil - and Mapper applies the same rule.
  def virtual_mapping?(mapping)
    mapping[:topic].nil?
  end

  # MAPPING_X_NAME is the optional alias other mappings use to reference this
  # one from a formula (e.g. {washer}), instead of the numeric MAPPING_X index
  # - which shifts whenever a mapping is added or removed further up (e.g. by
  # HELIOS-generated configs), silently pointing a formula at the wrong value.
  def validate_name!(mapping, index)
    name = mapping[:name]
    return unless name

    if name == 'value'
      invalid!(mapping, :name, '"value" is reserved for MAPPING_X_FORMULA')
    elsif !name.match?(MAPPING_NAME_REGEX)
      invalid!(mapping, :name,
               "#{name}. Must start with a lowercase letter or underscore, " \
               'followed by lowercase letters, digits or underscores',)
    elsif mappings.each_with_index.any? { |other, i| i != index && other[:name] == name }
      invalid!(mapping, :name, "name \"#{name}\" is already used by another mapping")
    end
  end

  # The ENV variable a mapping key comes from, e.g. MAPPING_1_FORMULA
  def mapping_var(mapping, key)
    "MAPPING_#{mapping[:mapping_group]}_#{key.upcase}"
  end

  # Refuses a mapping, naming the ENV variable that must be corrected
  def invalid!(mapping, key, reason)
    raise Config::Error, "Variable #{mapping_var(mapping, key)} is invalid: #{reason}"
  end

  # A variable that holds nothing but whitespace counts as unset
  def blank?(value)
    value.nil? || value.strip == ''
  end

  # Formats references the way they appear in a formula, e.g. "{washer}, {pv}"
  def braced(references)
    references.map { |reference| "{#{reference}}" }.join(', ')
  end

  def validate_mapping!(mapping, key, present: true, allow_list: nil)
    if present
      # Only a deprecated mapping can still hold a blank value here, because
      # mappings_from drops them while reading the ENV
      raise Config::Error, "Missing variable: #{mapping_var(mapping, key)}" if blank?(mapping[key])

      if allow_list && !allow_list.include?(mapping[key])
        invalid!(mapping, key, "#{mapping[key]}. Must be one of: #{allow_list.join(', ')}")
      end
    elsif mapping[key]
      raise Config::Error, "Unexpected variable: #{mapping_var(mapping, key)}"
    end
  end
end
