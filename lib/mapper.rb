require 'evaluator'

DEFAULT_HEARTBEAT_INTERVAL = 60

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
    config.mappings.select { |mapping| mapping[:topic].nil? }
  end

  def records_for(topic, message)
    return [] if message == ''

    mappings = mappings_for(topic)
    raise "Unknown mapping for topic: #{topic}" if mappings.empty?

    records = mappings.map { |mapping| records_for_mapping(mapping, message) }

    (records + virtual_records)
      .flatten
      .delete_if { |record| record[:value].nil? }
  end

  private

  def describe_mapping(mapping)
    mapping_target(mapping) + ' (' \
             "#{"#{mapping[:min]} ≥ " if mapping[:min]}#{mapping[:type]}" \
             "#{" ≤ #{mapping[:max]}" if mapping[:max]}" \
             "#{', converting NULL to 0' if mapping[:null_to_zero] == 'true'}" \
             "#{", named '#{mapping[:name]}'" if mapping[:name]}" \
             "#{", averaged every #{mapping[:aggregate_interval]}s" if mapping[:aggregate_interval]}" \
             "#{', not written to InfluxDB' if mapping[:skip_write] == 'true'}" \
             "#{dedup_description(mapping)}" \
             ')'
  end

  def dedup_description(mapping)
    return '' unless mapping[:dedup] == 'true'

    ", deduplicated (heartbeat #{mapping[:heartbeat_interval] || DEFAULT_HEARTBEAT_INTERVAL}s)"
  end

  def mapping_target(mapping)
    if signed?(mapping)
      "#{mapping[:measurement_positive]}:#{mapping[:field_positive]} (+) " \
        "#{mapping[:measurement_negative]}:#{mapping[:field_negative]} (-)"
    elsif mapping[:measurement] || mapping[:field]
      "#{mapping[:measurement]}:#{mapping[:field]}"
    else
      '(no InfluxDB field)'
    end
  end

  def records_for_mapping(mapping, message)
    value = value_from(message, mapping)
    remember_value(mapping, value)

    records_from(mapping, value)
  end

  # Recalculate all virtual mappings, since any of them might reference a
  # value that just changed.
  def virtual_records
    virtual_mappings.map do |mapping|
      value = virtual_value_from(mapping)
      remember_value(mapping, value)

      records_from(mapping, value)
    end
  end

  def records_from(mapping, value)
    return [] if value.nil?
    return [] if mapping[:skip_write] == 'true'

    value = throttled(mapping, value)
    return [] if value.nil?

    records =
      if signed?(mapping)
        map_with_sign(mapping, value)
      else
        map_default(mapping, value)
      end

    deduped(mapping, records)
  end

  # If MAPPING_X_DEDUP is set, a record is only passed through when its value
  # actually changed - except a zero value is always written once and then
  # suppressed for as long as it stays zero (no further signal needed), while
  # a repeated non-zero value is still written every MAPPING_X_HEARTBEAT_INTERVAL
  # seconds (default 60), to show that the sender is still alive.
  def deduped(mapping, records)
    return records unless mapping[:dedup] == 'true'

    interval = (mapping[:heartbeat_interval] || DEFAULT_HEARTBEAT_INTERVAL).to_f
    records.select { |record| due_for_write?(record, interval) }
  end

  def due_for_write?(record, interval)
    key = [record[:measurement], record[:field]]
    last = dedup_state[key]

    if last.nil? || last[:value] != record[:value]
      dedup_state[key] = { value: record[:value], written_at: monotonic_time }
      return true
    end

    return false if zero_ish?(record[:value])

    return false if monotonic_time - last[:written_at] < interval

    last[:written_at] = monotonic_time
    true
  end

  def zero_ish?(value)
    case value
    when Numeric
      value.zero?
    when true, false
      value == false
    else
      false
    end
  end

  def dedup_state
    @dedup_state ||= {}
  end

  # If MAPPING_X_AGGREGATE_INTERVAL is set, don't pass every single value
  # through - instead collect them and only return the average once the
  # interval has passed, so high-frequency updates get throttled down to one
  # write per interval. Returns the value unchanged if no interval is set.
  def throttled(mapping, value)
    interval = mapping[:aggregate_interval]&.to_f
    return value unless interval

    average = aggregate(mapping_key(mapping), value, interval)
    return nil if average.nil?

    convert_type(average, mapping)
  end

  # Collects values per mapping in a fixed window starting with the first
  # value received for it. Returns nil while the window is still open, or the
  # average of all values collected so far once the interval has elapsed -
  # at which point the window resets, to start fresh with the next value.
  def aggregate(key, value, interval)
    now = monotonic_time
    buffer = (aggregation_buffers[key] ||= { sum: 0.0, count: 0, window_start: now })

    buffer[:sum] += value
    buffer[:count] += 1

    return nil if now - buffer[:window_start] < interval

    average = buffer[:sum] / buffer[:count]
    aggregation_buffers.delete(key)
    average
  end

  def aggregation_buffers
    @aggregation_buffers ||= {}
  end

  def virtual_value_from(mapping)
    message = Evaluator.new(expression: mapping[:formula], data: fresh_values).run

    if message.nil? && mapping[:null_to_zero] != 'true'
      config.logger.warn "  Formula for #{mapping[:field] || mapping[:field_positive]} " \
                          "could not be evaluated#{missing_references_note(mapping)}, ignoring."
      return
    end

    convert_type(message, mapping)
  end

  # Describes which of the mapping's referenced values are missing or expired,
  # e.g. " (washer [sensor/power]: never received)". Falls back to a generic
  # note if the formula doesn't reference any (currently) unknown mapping.
  def missing_references_note(mapping)
    missing = missing_references(mapping)
    return ' (missing or outdated values)' if missing.empty?

    " (#{missing.map { |key| describe_reference(key) }.join(', ')})"
  end

  def missing_references(mapping)
    referenced_keys(mapping) - fresh_values.keys
  end

  def referenced_keys(mapping)
    mapping[:formula].scan(/{(.*?)}/).flatten.uniq
  end

  def describe_reference(key)
    mapping = mapping_by_key[key]
    label = mapping ? "#{key} [#{mapping[:topic] || mapping[:field] || mapping[:field_positive]}]" : key

    "#{label}: #{reference_status(key)}"
  end

  # Distinguishes a value that was never received at all from one that was
  # received but is now older than its own MAPPING_X_MAX_AGE.
  def reference_status(key)
    entry = last_values[key]
    return 'never received' unless entry

    age = (monotonic_time - entry[:received_at]).round
    "last received #{age}s ago, exceeds MAX_AGE of #{max_age_by_key[key].to_i}s"
  end

  # Remember the latest value of a mapping under its MAPPING_X_NAME, along
  # with the time it was received, so virtual mappings can reference it via a
  # placeholder like "{washer}" - and so it can expire via MAX_AGE. A mapping
  # without a NAME can't be referenced, so there's nothing to remember for it.
  def remember_value(mapping, value)
    return if value.nil? || mapping[:name].nil?

    last_values[mapping[:name]] = { value:, received_at: monotonic_time }
  end

  # Values for use in virtual mapping formulas, excluding any mapping whose
  # last value is older than its own MAPPING_X_MAX_AGE (in seconds), if set.
  def fresh_values
    last_values.filter_map do |key, entry|
      max_age = max_age_by_key[key]
      next if max_age && (monotonic_time - entry[:received_at]) > max_age

      [key, entry[:value]]
    end.to_h
  end

  def max_age_by_key
    @max_age_by_key ||= mapping_by_key.transform_values { |mapping| mapping[:max_age]&.to_f }
  end

  def mapping_by_key
    @mapping_by_key ||=
      config.mappings.select { |mapping| mapping[:name] }.to_h { |mapping| [mapping[:name], mapping] }
  end

  def last_values
    @last_values ||= {}
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
      field: mapping[:field],
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
      field: mapping[:field],
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
