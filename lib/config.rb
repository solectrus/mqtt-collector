require 'uri'
require 'null_logger'
require 'evaluator'

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

    # Ordering the virtual mappings also refuses a formula that forms a
    # cycle, so it has to happen here and not on the first message
    virtual_mappings
  end

  def influx_url
    "#{influx_schema}://#{influx_host}:#{influx_port}"
  end

  def mqtt_url
    "#{mqtt_schema}://#{mqtt_host}:#{mqtt_port}"
  end

  # A mapping without a topic gets its value from a formula referencing other
  # mappings. Config decides what that means, so Mapper cannot disagree.
  #
  # They come in calculation order: a mapping follows every mapping its
  # formula references. The order in the ENV therefore does not matter, so a
  # generated .env (e.g. by HELIOS) keeps working when it inserts a sensor
  # and renumbers everything after it.
  def virtual_mappings
    @virtual_mappings ||= virtual_mappings_in_calculation_order
  end

  # The mappings a formula can reference, by their MAPPING_X_NAME
  def mapping_by_name
    @mapping_by_name ||=
      mappings.select { |mapping| mapping[:name] }.to_h { |mapping| [mapping[:name], mapping] }
  end

  # The names a mapping's formula references, e.g. ["washer", "pv"]. A formula
  # never changes, so it is parsed once instead of once per message.
  def references_for(mapping)
    @references_for ||=
      Hash.new { |cache, formula| cache[formula] = Evaluator.variables_in(formula) }
    @references_for[mapping[:formula]]
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
      validate_formula_syntax!(mapping, :formula)

      if virtual_mapping?(mapping)
        validate_formula_present!(mapping)
        validate_formula_references!(mapping)
        validate_mapping!(mapping, :json_key, present: false)
        validate_mapping!(mapping, :json_path, present: false)
        validate_mapping!(mapping, :json_formula, present: false)
      else
        validate_mapping!(mapping, :topic)
        validate_formula_syntax!(mapping, :json_formula)
        validate_value_formula!(mapping)
      end

      validate_mapping!(mapping, :type, allow_list: MAPPING_TYPES)

      if mapping[:null_to_zero]
        validate_mapping!(mapping, :null_to_zero, allow_list: %w[true false])
      end

      if mapping[:skip_write]
        validate_mapping!(mapping, :skip_write, allow_list: %w[true false])
      end

      if mapping[:dedup]
        validate_mapping!(mapping, :dedup, allow_list: %w[true false])
      end

      validate_name!(mapping, index)
      validate_max_age!(mapping)
      validate_aggregate_interval!(mapping)
      validate_heartbeat_interval!(mapping)
      validate_destination!(mapping)
    end
  end

  def validate_max_age!(mapping)
    return unless mapping[:max_age]

    unless mapping[:name]
      raise Config::Error,
            "Variable #{mapping_var(mapping, :max_age)} requires #{mapping_var(mapping, :name)} to be set"
    end

    validate_seconds!(mapping, :max_age)
  end

  def validate_aggregate_interval!(mapping)
    return unless mapping[:aggregate_interval]

    validate_seconds!(mapping, :aggregate_interval)
  end

  def validate_heartbeat_interval!(mapping)
    return unless mapping[:heartbeat_interval]

    validate_seconds!(mapping, :heartbeat_interval)
  end

  # Every duration is a whole positive number of seconds. Mapper reads it with
  # to_f, which turns a typo into 0.0 - a value that silently disables the
  # option it belongs to. So the error is reported here instead.
  def validate_seconds!(mapping, key)
    value = mapping[key]
    return if value.match?(/\A\d+\z/) && value.to_i.positive?

    invalid!(mapping, key, "#{value}. Must be a positive number of seconds")
  end

  # A mapping without a topic is virtual and gets its value from a formula.
  # If it has neither, a forgotten topic is the more probable cause, so the
  # error names both variables.
  def validate_formula_present!(mapping)
    return if mapping[:formula]

    raise Config::Error,
          "Missing variable: #{mapping_var(mapping, :topic)} " \
          "(or #{mapping_var(mapping, :formula)} for a virtual mapping without a topic)"
  end

  # A broken formula is refused here. Otherwise it fails on every message,
  # with a warning that cannot tell a syntax error from a missing value.
  def validate_formula_syntax!(mapping, key)
    formula = mapping[key]
    return unless formula

    Evaluator.parse!(formula)
  rescue Evaluator::Error => e
    invalid!(mapping, key, e.message)
  end

  # MAPPING_X_FORMULA on a mapping with a topic calculates from the message
  # itself, which is available as {value}. The name of another mapping cannot
  # be resolved there - that is what a virtual mapping is for.
  def validate_value_formula!(mapping)
    return unless mapping[:formula]

    unusable = references_for(mapping) - %w[value]
    return if unusable.empty?

    invalid!(mapping, :formula,
             "#{braced(unusable)} cannot be used on a mapping with a topic, only {value}. " \
             'Leave out the topic to reference other mappings',)
  end

  def validate_formula_references!(mapping)
    references = references_for(mapping)

    validate_reference_present!(mapping, references)
    validate_known_references!(mapping, references)
  end

  # A virtual mapping calculates its value from other mappings. A formula
  # without a reference is a constant, which no message can ever change.
  def validate_reference_present!(mapping, references)
    return unless references.empty?

    invalid!(mapping, :formula, 'it must reference at least one MAPPING_X_NAME, e.g. {washer}')
  end

  # Every {...} of a virtual mapping's formula must match a MAPPING_X_NAME.
  # All names are known at start, so a typo is refused here. Otherwise the
  # mapping stays silent for the whole run, and the log shows the same
  # message as for a value that did not arrive yet.
  def validate_known_references!(mapping, references)
    unknown = references.reject { |reference| mapping_by_name.key?(reference) }
    return if unknown.empty?

    invalid!(mapping, :formula,
             "#{braced(unknown)} #{unknown.one? ? 'does' : 'do'} not match any MAPPING_X_NAME",)
  end

  def virtual_mappings_in_calculation_order
    ordered = []
    mappings.each do |mapping|
      append_after_references(mapping, [], ordered) if virtual_mapping?(mapping)
    end
    ordered
  end

  # Depth-first walk that appends a mapping after every mapping its formula
  # references. "path" holds the mappings of the current walk, so a formula
  # leading back into it cannot be calculated at all.
  #
  # Identity comparison throughout, because two mappings can hold equal values.
  def append_after_references(mapping, path, ordered)
    return if ordered.any? { |other| other.equal?(mapping) }

    references_for(mapping).each do |reference|
      other = mapping_by_name[reference]
      next unless virtual_mapping?(other)

      validate_no_cycle!(mapping, reference, other, path)
      append_after_references(other, path + [mapping], ordered)
    end

    ordered << mapping
  end

  # A formula that leads back to a mapping already being calculated has no
  # value to start from, so it is refused instead of silently using the
  # result of the message before.
  def validate_no_cycle!(mapping, reference, other, path)
    if other.equal?(mapping)
      invalid!(mapping, :formula, "{#{reference}} refers to the mapping itself")
    end
    return unless path.any? { |visited| visited.equal?(other) }

    cycle = path.drop_while { |visited| !visited.equal?(other) } + [mapping, other]
    invalid!(mapping, :formula,
             "{#{reference}} closes a cycle: #{cycle.map { |m| label_for(m) }.join(' -> ')}. " \
             'A formula cannot depend on its own result',)
  end

  # How a mapping is named in an error, preferring its MAPPING_X_NAME
  def label_for(mapping)
    mapping[:name] || "MAPPING_#{mapping[:mapping_group]}"
  end

  # A mapping that is never written to InfluxDB does not need a destination
  def validate_destination!(mapping)
    return if mapping[:skip_write] == 'true'

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

  # Formats references the way they appear in a formula, e.g. "{washer}, {pv}"
  def braced(references)
    references.map { |reference| "{#{reference}}" }.join(', ')
  end

  # A variable that holds nothing but whitespace counts as unset
  def blank?(value)
    value.nil? || value.strip == ''
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
