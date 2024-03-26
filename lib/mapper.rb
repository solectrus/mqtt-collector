class Mapper
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def topics
    @topics ||= config.mappings.map { |mapping| mapping[:topic] }.sort
  end

  def formatted_mapping(topic)
    mapping = mapping_for(topic)

    result = if signed?(mapping)
               "#{mapping[:measurement_positive]}:#{mapping[:field_positive]} (+) " \
               "#{mapping[:measurement_negative]}:#{mapping[:field_negative]} (-)"
             else
               "#{mapping[:measurement]}:#{mapping[:field]}"
             end

    result += " (#{mapping[:type]})"
    result
  end

  def records_for(topic, message)
    return [] if message == ''

    mapping = mapping_for(topic)
    raise "Unknown mapping for topic: #{topic}" unless mapping

    value = value_from(message, mapping)
    if signed?(mapping)
      map_with_sign(mapping, value)
    else
      map_default(mapping, value)
    end
  end

  private

  def signed?(mapping)
    (mapping.keys & %i[field_positive field_negative measurement_positive measurement_negative]).size == 4
  end

  def value_from(message, mapping)
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
