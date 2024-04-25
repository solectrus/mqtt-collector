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

        result += " (#{mapping[:type]})"
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
    if mapping[:json_key]
      message = extract_from_json(message, mapping)
      return if message.nil?
    end

    case mapping[:type]
    when 'float'
      begin
        message.to_f
      rescue StandardError
        config.logger.warn "Failed to convert #{message} to float"
        nil
      end
    when 'integer'
      begin
        message.to_f.round
      rescue StandardError
        config.logger.warn "Failed to convert #{message} to integer"
        nil
      end
    when 'boolean'
      %w[true TRUE ok OK yes YES 1].include?(message)
    when 'string'
      message.to_s
    end
  end

  def extract_from_json(message, mapping)
    raise "Message is not a string: #{message}" unless message.is_a? String

    begin
      json = JSON.parse(message)
      message = json[mapping[:json_key]]
    rescue JSON::ParserError
      config.logger.warn "Failed to parse JSON: #{message}"
      nil
    end
  end

  def map_with_sign(mapping, value)
    [
      {
        measurement: mapping[:measurement_negative],
        field: mapping[:field_negative],
        value: value.negative? ? value.abs : 0,
      },
      {
        measurement: mapping[:measurement_positive],
        field: mapping[:field_positive],
        value: value.positive? ? value : 0,
      },
    ]
  end

  def map_default(mapping, value)
    [{ measurement: mapping[:measurement], field: mapping[:field], value: }]
  end

  def mappings_for(topic)
    config.mappings.select { |mapping| mapping[:topic] == topic }
  end
end
