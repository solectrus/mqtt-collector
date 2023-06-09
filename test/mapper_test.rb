require 'test_helper'
require 'mapper'
require 'config'

VALID_ENV = {
  MQTT_HOST: '1.2.3.4',
  MQTT_PORT: '1883',
  MQTT_USERNAME: 'username',
  MQTT_PASSWORD: 'password',
  MQTT_SSL: 'false',
  # ---
  INFLUX_HOST: 'influx.example.com',
  INFLUX_SCHEMA: 'https',
  INFLUX_PORT: '443',
  INFLUX_TOKEN: 'this.is.just.an.example',
  INFLUX_ORG: 'solectrus',
  INFLUX_BUCKET: 'my-bucket',
  # ---
  MQTT_TOPIC_HOUSE_POW: 'senec/0/ENERGY/GUI_HOUSE_POW',
  MQTT_TOPIC_GRID_POW: 'senec/0/ENERGY/GUI_GRID_POW',
  MQTT_TOPIC_BAT_CHARGE_CURRENT: 'senec/0/ENERGY/GUI_BAT_DATA_CURRENT',
  MQTT_TOPIC_BAT_FUEL_CHARGE: 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE',
  MQTT_TOPIC_BAT_POWER: 'senec/0/ENERGY/GUI_BAT_DATA_POWER',
  MQTT_TOPIC_BAT_VOLTAGE: 'senec/0/ENERGY/GUI_BAT_DATA_VOLTAGE',
  MQTT_TOPIC_CASE_TEMP: 'senec/0/TEMPMEASURE/CASE_TEMP',
  MQTT_TOPIC_CURRENT_STATE: 'senec/0/ENERGY/STAT_STATE_Text',
  MQTT_TOPIC_MPP1_POWER: 'senec/0/PV1/MPP_POWER/0',
  MQTT_TOPIC_MPP2_POWER: 'senec/0/PV1/MPP_POWER/1',
  MQTT_TOPIC_MPP3_POWER: 'senec/0/PV1/MPP_POWER/2',
  MQTT_TOPIC_INVERTER_POWER: 'senec/0/ENERGY/GUI_INVERTER_POWER',
  MQTT_TOPIC_WALLBOX_CHARGE_POWER: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
}.freeze

class MapperTest < Minitest::Test
  def default_config
    @default_config ||= ClimateControl.modify(VALID_ENV) { Config.from_env }
  end

  def mapper(config: nil)
    Mapper.new(config: config || default_config)
  end

  def test_topics
    assert_equal %w[
                   senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE
                   senec/0/ENERGY/GUI_BAT_DATA_POWER
                   senec/0/ENERGY/GUI_GRID_POW
                   senec/0/ENERGY/GUI_HOUSE_POW
                   senec/0/ENERGY/GUI_INVERTER_POWER
                   senec/0/ENERGY/STAT_STATE_Text
                   senec/0/PV1/MPP_POWER/0
                   senec/0/PV1/MPP_POWER/1
                   senec/0/PV1/MPP_POWER/2
                   senec/0/TEMPMEASURE/CASE_TEMP
                   senec/0/WALLBOX/APPARENT_CHARGING_POWER/0
                 ],
                 mapper.topics
  end

  def test_call_with_inverter_power
    hash = mapper.call('senec/0/ENERGY/GUI_INVERTER_POWER', '123.45')

    assert_equal({ 'inverter_power' => 123 }, hash)
  end

  def test_call_with_mpp1_power
    hash = mapper.call('senec/0/PV1/MPP_POWER/0', '123.45')

    assert_equal({ 'mpp1_power' => 123 }, hash)
  end

  def test_call_with_mpp2_power
    hash = mapper.call('senec/0/PV1/MPP_POWER/1', '123.45')

    assert_equal({ 'mpp2_power' => 123 }, hash)
  end

  def test_call_with_mpp3_power
    hash = mapper.call('senec/0/PV1/MPP_POWER/2', '123.45')

    assert_equal({ 'mpp3_power' => 123 }, hash)
  end

  def test_call_with_house_pow
    hash = mapper.call('senec/0/ENERGY/GUI_HOUSE_POW', '123.45')

    assert_equal({ 'house_power' => 123 }, hash)
  end

  def test_call_with_bat_fuel_charge
    hash = mapper.call('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE', '123.45')

    assert_equal({ 'bat_fuel_charge' => 123.5 }, hash)
  end

  def test_call_with_wallbox_charge_power
    hash = mapper.call('senec/0/WALLBOX/APPARENT_CHARGING_POWER/0', '123.45')

    assert_equal({ 'wallbox_charge_power' => 123 }, hash)
  end

  def test_call_with_bat_power_plus
    hash = mapper.call('senec/0/ENERGY/GUI_BAT_DATA_POWER', '123.45')

    assert_equal({ 'bat_power_plus' => 123, 'bat_power_minus' => 0 }, hash)
  end

  def test_call_with_bat_power_minus
    hash = mapper.call('senec/0/ENERGY/GUI_BAT_DATA_POWER', '-123.45')

    assert_equal({ 'bat_power_plus' => 0, 'bat_power_minus' => 123 }, hash)
  end

  def test_call_with_bat_power_minus_with_flip
    other_config =
      ClimateControl.modify(VALID_ENV.merge(MQTT_FLIP_BAT_POWER: 'true')) do
        Config.from_env
      end

    hash =
      mapper(config: other_config).call(
        'senec/0/ENERGY/GUI_BAT_DATA_POWER',
        '-123.45',
      )

    assert_equal({ 'bat_power_plus' => 123, 'bat_power_minus' => 0 }, hash)
  end

  def test_call_with_grid_power_plus
    hash = mapper.call('senec/0/ENERGY/GUI_GRID_POW', '123.45')

    assert_equal({ 'grid_power_plus' => 123, 'grid_power_minus' => 0 }, hash)
  end

  def test_call_with_grid_power_minus
    hash = mapper.call('senec/0/ENERGY/GUI_GRID_POW', '-123.45')

    assert_equal({ 'grid_power_plus' => 0, 'grid_power_minus' => 123 }, hash)
  end

  def test_call_with_current_state
    hash = mapper.call('senec/0/ENERGY/STAT_STATE_Text', 'LOADING')

    assert_equal({ 'current_state' => 'LOADING' }, hash)
  end

  def test_call_with_case_temp
    hash = mapper.call('senec/0/TEMPMEASURE/CASE_TEMP', '35.2')

    assert_equal({ 'case_temp' => 35.2 }, hash)
  end

  def test_call_with_unknown_topic
    assert_raises RuntimeError do
      mapper.call('this/is/an/unknown/topic', 'foo!')
    end
  end
end
