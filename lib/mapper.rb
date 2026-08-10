require 'evaluator'

class Mapper
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def topics
    @topics ||=
      config.mappings.filter_map { |mapping| mapping[:topic] }.sort.uniq
  end

  def formatted_mapping(topic)
    mappings_for(topic).map { |mapping| describe_mapping(mapping) }.join(', ')
  end

  def formatted_virtual_mapping(mapping)
    "#{describe_mapping(mapping)} = #{mapping[:formula]}"
  end

  def virtual_mappings
    config.virtual_mappings
  end

  def records_for(topic, message)
    return [] if message == ''

    mappings = mappings_for(topic)
    raise "Unknown mapping for topic: #{topic}" if mappings.empty?

    # Names of the values this message changes, extended by every virtual
    # mapping calculated from them
    updated = []
    records = mappings.flat_map { |mapping| records_for_mapping(mapping, message, updated) }

    (records + virtual_records(updated)).delete_if { |record| record[:value].nil? }
  end

  private

  def describe_mapping(mapping)
    result =
      if signed?(mapping)
        "#{mapping[:measurement_positive]}:#{mapping[:field_positive]} (+) " \
          "#{mapping[:measurement_negative]}:#{mapping[:field_negative]} (-)"
      else
        "#{mapping[:measurement]}:#{mapping[:field]}"
      end

    result + ' (' \
             "#{"#{mapping[:min]} ≥ " if mapping[:min]}#{mapping[:type]}" \
             "#{" ≤ #{mapping[:max]}" if mapping[:max]}" \
             "#{', converting NULL to 0' if mapping[:null_to_zero] == 'true'}" \
             "#{", named '#{mapping[:name]}'" if mapping[:name]}" \
             ')'
  end

  def records_for_mapping(mapping, message, updated)
    value = value_from(message, mapping)
    remember_value(mapping, value, updated)

    map_value(mapping, value)
  end

  # Recalculate the virtual mappings that reference one of the changed
  # values. A virtual mapping whose inputs did not change would write the
  # same value again, so it is skipped. A chained virtual mapping sees the
  # names added here, because Config hands them over in calculation order.
  def virtual_records(updated)
    virtual_mappings.flat_map do |mapping|
      next [] unless config.references_for(mapping).intersect?(updated)

      value = virtual_value_from(mapping)
      remember_value(mapping, value, updated, inputs: config.references_for(mapping))

      map_value(mapping, value)
    end
  end

  def map_value(mapping, value)
    if value && signed?(mapping)
      map_with_sign(mapping, value)
    else
      map_default(mapping, value)
    end
  end

  def virtual_value_from(mapping)
    # One snapshot for the calculation and the warning, so a value cannot
    # expire between the two and make them disagree
    values = fresh_values
    message = Evaluator.new(expression: mapping[:formula], data: values).run

    if message.nil? && mapping[:null_to_zero] != 'true'
      warn_unresolved(mapping, values)
      return
    end

    unresolved_states.delete(mapping[:mapping_group])
    convert_type(message, mapping)
  end

  # A mapping that stays unresolved (e.g. because a sensor is gone) would
  # repeat the same warning for every message of the other references. The
  # warning is logged only while the situation changes. A calculation that
  # works again clears the state, so the next dropout is logged again.
  def warn_unresolved(mapping, values)
    missing = config.references_for(mapping) - values.keys

    # Which references are unresolved, and why. The age in seconds is left
    # out, because it changes with every message.
    state = missing.map { |key| [key, reference_state(key)] }
    return if unresolved_states[mapping[:mapping_group]] == state

    unresolved_states[mapping[:mapping_group]] = state

    config.logger.warn "  Formula for #{target_field(mapping)} " \
                       "could not be evaluated#{missing_references_note(missing)}, ignoring."
  end

  def unresolved_states
    @unresolved_states ||= {}
  end

  # Describes which of the mapping's referenced values are missing or expired,
  # e.g. " (washer [sensor/power]: never received)". If every reference has a
  # value, the formula itself is at fault, e.g. it divides by zero or
  # calculates with a string.
  def missing_references_note(missing)
    return ' (all referenced values are known, so check the formula itself)' if missing.empty?

    " (#{missing.map { |key| describe_reference(key) }.join(', ')})"
  end

  # Config refuses a formula referencing an unknown name, so every reference
  # has a mapping here.
  def describe_reference(key)
    mapping = config.mapping_by_name[key]
    source = mapping[:topic] || 'virtual'

    "#{key} [#{source}]: #{reference_status(key)}"
  end

  # Distinguishes a value that was never received at all from one that was
  # received but is now older than its own MAPPING_X_MAX_AGE. The warning and
  # the state that suppresses it share this answer, so they cannot disagree.
  def reference_state(key)
    last_values.key?(key) ? :expired : :never
  end

  # The MAX_AGE named here is the one that actually expired the value, which
  # for a virtual mapping can be inherited from one of its inputs.
  def reference_status(key)
    return 'never received' if reference_state(key) == :never

    entry = last_values[key]
    age = (monotonic_time - entry[:received_at]).round
    max_age = (entry[:expires_at] - entry[:received_at]).round

    "last received #{age}s ago, exceeds MAX_AGE of #{max_age}s"
  end

  # Remember the latest value of a mapping under its MAPPING_X_NAME, along
  # with the time it was received, so virtual mappings can reference it via a
  # placeholder like "{washer}" - and so it can expire via MAX_AGE. A mapping
  # without a NAME can't be referenced, so there's nothing to remember for it.
  # The name goes to "updated", which selects the virtual mappings to
  # recalculate.
  def remember_value(mapping, value, updated, inputs: [])
    return if value.nil? || mapping[:name].nil?

    last_values[mapping[:name]] = { value:, **freshness(mapping, inputs) }
    updated << mapping[:name]
  end

  # When a value was received, and when it stops being usable (nil = never).
  # A calculated value inherits both from the oldest value it was calculated
  # from: it is only as fresh as its inputs, and expires as soon as the first
  # of them does. Without that, MAX_AGE on a source mapping would stop the
  # first link of a chain only. A virtual mapping in between never expires by
  # itself, so everything after it would keep writing from a stale input.
  def freshness(mapping, inputs)
    now = monotonic_time
    max_age = max_age_by_key[mapping[:name]]
    entries = inputs.filter_map { |key| last_values[key] }

    {
      received_at: [now, *entries.map { |entry| entry[:received_at] }].min,
      expires_at: [
        (now + max_age if max_age),
        *entries.map { |entry| entry[:expires_at] },
      ].compact.min,
    }
  end

  # Values for use in virtual mapping formulas, excluding every value that
  # outlived its MAPPING_X_MAX_AGE - its own, or an inherited one.
  def fresh_values
    now = monotonic_time

    last_values.filter_map do |key, entry|
      next if entry[:expires_at] && now > entry[:expires_at]

      [key, entry[:value]]
    end.to_h
  end

  def max_age_by_key
    @max_age_by_key ||= config.mapping_by_name.transform_values { |mapping| mapping[:max_age]&.to_f }
  end

  def last_values
    @last_values ||= {}
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # The field a warning names. A signed mapping has no :field, so its
  # positive one stands for the pair.
  def target_field(mapping)
    mapping[:field] || mapping[:field_positive]
  end

  def signed?(mapping)
    (
      mapping.keys &
        %i[
          field_positive
          field_negative
          measurement_positive
          measurement_negative
        ]
    ).size == 4
  end

  def value_from(message, mapping)
    if mapping[:json_key] || mapping[:json_path]
      message = extract_from_json(message, mapping)
    elsif mapping[:json_formula]
      message = evaluate_from_json(message, mapping[:json_formula])
    elsif mapping[:formula]
      message = evaluate_from_json({ value: message }.to_json, mapping[:formula])
    end

    if message.nil? && mapping[:null_to_zero] != 'true'
      config.logger.warn '  Value not found, ignoring.'
      return
    end

    convert_type(message, mapping)
  end

  def convert_type(message, mapping)
    case mapping[:type]
    when 'float'
      convert_float(message, mapping)
    when 'integer'
      convert_integer(message, mapping)
    when 'boolean'
      convert_boolean(message, mapping)
    when 'string'
      convert_string(message, mapping)
    end
  end

  def convert_float(message, mapping)
    ensure_min_max(
      field: target_field(mapping),
      value: (begin
        message.to_f
      rescue StandardError
        config.logger.warn "Failed to convert #{message} to float"
        nil
      end),
      min: mapping[:min]&.to_f,
      max: mapping[:max]&.to_f,
    )
  end

  def convert_integer(message, mapping)
    ensure_min_max(
      field: target_field(mapping),
      value: (begin
        message.to_f.round
      rescue StandardError
        config.logger.warn "Failed to convert #{message} to integer"
        nil
      end),
      min: mapping[:min]&.to_i,
      max: mapping[:max]&.to_i,
    )
  end

  def convert_boolean(message, _mapping) # rubocop:disable Naming/PredicateMethod
    %w[true ok yes on 1].include?(message.to_s.downcase)
  end

  def convert_string(message, _mapping)
    message.to_s
  end

  def extract_from_json(message, mapping)
    raise "Message is not a string: #{message}" unless message.is_a? String

    json = parse_json(message)
    return unless json

    if mapping[:json_path]
      JsonPath.new(mapping[:json_path]).first(json)
    elsif mapping[:json_key]
      json[mapping[:json_key]]
    end
  end

  def evaluate_from_json(message, formula)
    json = parse_json(message)
    return unless json

    Evaluator.new(expression: formula, data: json).run
  end

  def parse_json(message)
    JSON.parse(message)
  rescue JSON::ParserError
    config.logger.warn "Failed to parse JSON: #{message}"
    nil
  end

  def map_with_sign(mapping, value)
    [
      {
        measurement: mapping[:measurement_negative],
        field: mapping[:field_negative],
        value: value.negative? ? value.abs : convert_type('0', mapping),
      },
      {
        measurement: mapping[:measurement_positive],
        field: mapping[:field_positive],
        value: value.positive? ? value : convert_type('0', mapping),
      },
    ]
  end

  def map_default(mapping, value)
    [{ measurement: mapping[:measurement], field: mapping[:field], value: }]
  end

  def mappings_for(topic)
    config.mappings.select { |mapping| mapping[:topic] == topic }
  end

  def ensure_min_max(field:, value:, min:, max:)
    return value unless value && (max || min)

    if max && value > max
      config.logger.warn "  Ignoring #{field}: #{value} exceeds maximum of #{max}"
      return
    end

    if min && value < min
      config.logger.warn "  Ignoring #{field}: #{value} is below minimum of #{min}"
      return
    end

    value
  end
end
