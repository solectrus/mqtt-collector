class Mapper
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def topics
    config.mappings.map { |mapping| mapping[:topic] }.sort
  end

  def records_for(topic, message)
    return [] if message == ''

    mapping = mapping_for(topic)
    raise "Unknown mapping for topic: #{topic}" unless mapping

    value = value_from(message)
    if (mapping.keys & %i[field_positive field_negative measurement_positive measurement_negative]).size == 4
      map_with_sign(mapping, value)
    elsif (mapping.keys & %i[field measurement]).size == 2
      map_default(mapping, value)
    end
  end

  private

  def value_from(message)
    case message
    when /^-?\d+.?\d+$/
      message.to_f.round
    when /true/i
      true
    when /false/i
      false
    when String
      message
    else
      raise "Unknown message type: #{message}"
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
    [
      {
        measurement: mapping[:measurement],
        field: mapping[:field],
        value:,
      },
    ]
  end

  def mapping_for(topic)
    config.mappings.find { |mapping| mapping[:topic] == topic }
  end
end
