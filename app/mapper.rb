class Mapper
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def topics
    topic_keys.filter_map { |key| config.send("mqtt_topic_#{key}") }.sort
  end

  def call(topic, message)
    method_name = topic_to_method(topic)
    raise "Unknown topic: #{topic}" unless method_name

    send(method_name, message)
  end

  private

  def topic_keys
    private_methods.grep(/^map_/).map { |m| m.to_s.sub('map_', '') }
  end

  def topic_to_method(topic)
    method = topic_keys.find { |key| config.send("mqtt_topic_#{key}") == topic }
    return unless method

    "map_#{method}"
  end

  # To add a new mapping, add a new method here and a new config key in app/config.rb
  # The method name must be prefixed with `map_` and the config key must be prefixed with `mqtt_topic_`
  # The method must return a hash with field name and value to be sent to InfluxDB

  def map_inverter_power(value)
    { 'inverter_power' => value.to_f.round }
  end

  def map_mpp1_power(value)
    { 'mpp1_power' => value.to_f.round }
  end

  def map_mpp2_power(value)
    { 'mpp2_power' => value.to_f.round }
  end

  def map_mpp3_power(value)
    { 'mpp3_power' => value.to_f.round }
  end

  def map_house_pow(value)
    { 'house_power' => value.to_f.round }
  end

  def map_bat_fuel_charge(value)
    { 'bat_fuel_charge' => value.to_f.round(1) }
  end

  def map_wallbox_charge_power(value)
    { 'wallbox_charge_power' => value.to_f.round }
  end

  def map_bat_power(value)
    value = value.to_f.round
    value = -value if config.mqtt_flip_bat_power

    if value.negative?
      # From battery
      { 'bat_power_plus' => 0, 'bat_power_minus' => -value }
    else
      # To battery
      { 'bat_power_plus' => value, 'bat_power_minus' => 0 }
    end
  end

  def map_grid_pow(value)
    value = value.to_f.round

    if value.negative?
      # To grid
      { 'grid_power_plus' => 0, 'grid_power_minus' => -value }
    else
      # From grid
      { 'grid_power_plus' => value, 'grid_power_minus' => 0 }
    end
  end

  def map_current_state(value)
    value.sub!(/ \(\d+\)/, '')

    { 'current_state' => value }
  end

  def map_case_temp(value)
    { 'case_temp' => value.to_f.round(1) }
  end
end
