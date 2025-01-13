require 'evaluator'

class Mapper
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def topics
    @topics ||= config.mappings.map { |mapping| mapping[:topic] }.sort.uniq
  end

  def formatted_mapping(topic)
    mappings_for(topic)
      .map do |mapping|
        result =
          if signed?(mapping)
            "#{mapping[:measurement_positive]}:#{mapping[:field_positive]} (+) " \
              "#{mapping[:measurement_negative]}:#{mapping[:field_negative]} (-)"
          else
            "#{mapping[:measurement]}:#{mapping[:field]}"
          end

        result += " (#{"#{mapping[:min]} ≥ " if mapping[:min]}#{mapping[:type]}#{" ≤ #{mapping[:max]}" if mapping[:max]})"
        result
      end
      .join(', ')
  end

  def records_for(topic, message)
    return [] if message == ''

    mappings = mappings_for(topic)
    raise "Unknown mapping for topic: #{topic}" if mappings.empty?

    mappings
      .map do |mapping|
        value = value_from(message, mapping)
        if signed?(mapping)
          map_with_sign(mapping, value)
        else
          map_default(mapping, value)
        end
      end
      .flatten
      .delete_if { |record| record[:value].nil? }
  end

  private

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
    unless message
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

  def convert_boolean(message, _mapping)
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
