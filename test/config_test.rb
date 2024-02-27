require 'test_helper'
require 'climate_control'

class ConfigTest < Minitest::Test
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
    MQTT_TOPIC_BAT_FUEL_CHARGE: 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE',
    MQTT_TOPIC_BAT_POWER: 'senec/0/ENERGY/GUI_BAT_DATA_POWER',
    MQTT_TOPIC_CASE_TEMP: 'senec/0/TEMPMEASURE/CASE_TEMP',
    MQTT_TOPIC_CURRENT_STATE: 'senec/0/ENERGY/STAT_STATE_Text',
    MQTT_TOPIC_MPP1_POWER: 'senec/0/PV1/MPP_POWER/0',
    MQTT_TOPIC_MPP2_POWER: 'senec/0/PV1/MPP_POWER/1',
    MQTT_TOPIC_MPP3_POWER: 'senec/0/PV1/MPP_POWER/2',
    MQTT_TOPIC_INVERTER_POWER: 'senec/0/ENERGY/GUI_INVERTER_POWER',
    MQTT_TOPIC_WALLBOX_CHARGE_POWER:
      'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
    MQTT_TOPIC_HEATPUMP_POWER: 'somewhere/HEATPUMP/POWER',
  }.freeze

  def config
    @config ||= ClimateControl.modify(VALID_ENV) { Config.from_env }
  end

  def test_valid_options
    assert(config)
  end

  def test_mqtt_credentials
    VALID_ENV
      .slice(:MQTT_HOST, :MQTT_PORT, :MQTT_USERNAME, :MQTT_PASSWORD)
      .each { |key, value| assert_equal value, config.send(key.downcase) }

    assert_equal 'mqtt://1.2.3.4:1883', config.mqtt_url
    refute config.mqtt_ssl
  end

  def test_mqtt_topics
    VALID_ENV
      .slice(
        :MQTT_TOPIC_HOUSE_POW,
        :MQTT_TOPIC_GRID_POW,
        :MQTT_TOPIC_BAT_FUEL_CHARGE,
        :MQTT_TOPIC_BAT_POWER,
        :MQTT_TOPIC_CASE_TEMP,
        :MQTT_TOPIC_CURRENT_STATE,
        :MQTT_TOPIC_MPP1_POWER,
        :MQTT_TOPIC_MPP2_POWER,
        :MQTT_TOPIC_MPP3_POWER,
        :MQTT_TOPIC_INVERTER_POWER,
        :MQTT_TOPIC_WALLBOX_CHARGE_POWER,
        :MQTT_TOPIC_HEATPUMP_POWER,
      )
      .each { |key, value| assert_equal value, config.send(key.downcase) }
  end

  def test_mqtt_flip_bat_power_true
    config_flip =
      ClimateControl.modify(VALID_ENV.merge(MQTT_FLIP_BAT_POWER: 'true')) do
        Config.from_env
      end

    assert config_flip.mqtt_flip_bat_power
  end

  def test_mqtt_flip_bat_power_false
    config_flip =
      ClimateControl.modify(VALID_ENV.merge(MQTT_FLIP_BAT_POWER: 'false')) do
        Config.from_env
      end

    refute config_flip.mqtt_flip_bat_power
  end

  def test_mqtt_flip_grid_pow_true
    config_flip =
      ClimateControl.modify(VALID_ENV.merge(MQTT_FLIP_GRID_POW: 'true')) do
        Config.from_env
      end

    assert config_flip.mqtt_flip_grid_pow
  end

  def test_mqtt_flip_grid_pow_false
    config_flip =
      ClimateControl.modify(VALID_ENV.merge(MQTT_FLIP_GRID_POW: 'false')) do
        Config.from_env
      end

    refute config_flip.mqtt_flip_grid_pow
  end

  def test_influx_methods
    VALID_ENV
      .slice(
        :INFLUX_HOST,
        :INFLUX_SCHEMA,
        :INFLUX_PORT,
        :INFLUX_TOKEN,
        :INFLUX_ORG,
        :INFLUX_BUCKET,
      )
      .each { |key, value| assert_equal value, config.send(key.downcase) }

    assert_equal 'https://influx.example.com:443', config.influx_url
  end

  def test_invalid_options
    assert_raises(Exception) { Config.new({}) }
    assert_raises(Exception) { Config.new(influx_host: 'this is no host') }
  end
end
