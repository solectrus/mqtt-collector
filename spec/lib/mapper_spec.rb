require 'mapper'
require 'config'
require 'climate_control'

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
  MQTT_TOPIC_WALLBOX_CHARGE_POWER: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
  MQTT_TOPIC_WALLBOX_CHARGE_POWER0: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
  MQTT_TOPIC_WALLBOX_CHARGE_POWER1: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/1',
  MQTT_TOPIC_WALLBOX_CHARGE_POWER2: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/2',
  MQTT_TOPIC_WALLBOX_CHARGE_POWER3: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/3',
  MQTT_TOPIC_POWER_RATIO: 'senec/0/PV1/POWER_RATIO',
  MQTT_TOPIC_CURRENT_STATE_OK: 'somewhere/STAT_STATE_OK',
  MQTT_TOPIC_HEATPUMP_POWER: 'somewhere/HEATPUMP/POWER',
}.freeze

EXPECTED_TOPICS = %w[
  senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE
  senec/0/ENERGY/GUI_BAT_DATA_POWER
  senec/0/ENERGY/GUI_GRID_POW
  senec/0/ENERGY/GUI_HOUSE_POW
  senec/0/ENERGY/GUI_INVERTER_POWER
  senec/0/ENERGY/STAT_STATE_Text
  senec/0/PV1/MPP_POWER/0
  senec/0/PV1/MPP_POWER/1
  senec/0/PV1/MPP_POWER/2
  senec/0/PV1/POWER_RATIO
  senec/0/TEMPMEASURE/CASE_TEMP
  senec/0/WALLBOX/APPARENT_CHARGING_POWER/0
  senec/0/WALLBOX/APPARENT_CHARGING_POWER/1
  senec/0/WALLBOX/APPARENT_CHARGING_POWER/2
  senec/0/WALLBOX/APPARENT_CHARGING_POWER/3
  somewhere/HEATPUMP/POWER
  somewhere/STAT_STATE_OK
].freeze

describe Mapper do
  def default_config
    @default_config ||= ClimateControl.modify(VALID_ENV) { Config.from_env }
  end

  def mapper(config: nil)
    Mapper.new(config: config || default_config)
  end

  it 'has topis' do
    expect(mapper.topics).to eq(EXPECTED_TOPICS)
  end

  it 'maps inverter power' do
    hash = mapper.call('senec/0/ENERGY/GUI_INVERTER_POWER', '123.45')

    expect(hash).to eq({ 'inverter_power' => 123 })
  end

  it 'maps mpp1_power' do
    hash = mapper.call('senec/0/PV1/MPP_POWER/0', '123.45')

    expect(hash).to eq({ 'mpp1_power' => 123 })
  end

  it 'maps mpp2_power' do
    hash = mapper.call('senec/0/PV1/MPP_POWER/1', '123.45')

    expect(hash).to eq({ 'mpp2_power' => 123 })
  end

  it 'maps mpp3_power' do
    hash = mapper.call('senec/0/PV1/MPP_POWER/2', '123.45')

    expect(hash).to eq({ 'mpp3_power' => 123 })
  end

  it 'maps house_power' do
    hash = mapper.call('senec/0/ENERGY/GUI_HOUSE_POW', '123.45')

    expect(hash).to eq({ 'house_power' => 123 })
  end

  it 'maps bat_fuel_charge' do
    hash = mapper.call('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE', '123.45')

    expect(hash).to eq({ 'bat_fuel_charge' => 123.5 })
  end

  it 'maps wallbox_charge_power' do
    hash = mapper.call('senec/0/WALLBOX/APPARENT_CHARGING_POWER/0', '123.45')

    expect(hash).to eq({ 'wallbox_charge_power' => 123 })
    # TODO: assert_equal({ 'wallbox_charge_power0' => 123 }, hash)
  end

  it 'maps wallbox_charge_power1' do
    hash = mapper.call('senec/0/WALLBOX/APPARENT_CHARGING_POWER/1', '123.45')

    expect(hash).to eq({ 'wallbox_charge_power1' => 123 })
  end

  it 'maps wallbox_charge_power2' do
    hash = mapper.call('senec/0/WALLBOX/APPARENT_CHARGING_POWER/2', '123.45')

    expect(hash).to eq({ 'wallbox_charge_power2' => 123 })
  end

  it 'maps wallbox_charge_power3' do
    hash = mapper.call('senec/0/WALLBOX/APPARENT_CHARGING_POWER/3', '123.45')

    expect(hash).to eq({ 'wallbox_charge_power3' => 123 })
  end

  it 'maps bat_power_plus' do
    hash = mapper.call('senec/0/ENERGY/GUI_BAT_DATA_POWER', '123.45')

    expect(hash).to eq({ 'bat_power_plus' => 123, 'bat_power_minus' => 0 })
  end

  it 'maps bat_power' do
    hash = mapper.call('senec/0/ENERGY/GUI_BAT_DATA_POWER', '-123.45')

    expect(hash).to eq({ 'bat_power_plus' => 0, 'bat_power_minus' => 123 })
  end

  it 'maps bat_power_plus with flipping' do
    other_config =
      ClimateControl.modify(VALID_ENV.merge(MQTT_FLIP_BAT_POWER: 'true')) do
        Config.from_env
      end

    hash =
      mapper(config: other_config).call(
        'senec/0/ENERGY/GUI_BAT_DATA_POWER',
        '-123.45',
      )

    expect(hash).to eq({ 'bat_power_plus' => 123, 'bat_power_minus' => 0 })
  end

  it 'maps grid_power_plus' do
    hash = mapper.call('senec/0/ENERGY/GUI_GRID_POW', '123.45')

    expect(hash).to eq({ 'grid_power_plus' => 123, 'grid_power_minus' => 0 })
  end

  it 'maps grid_power_minus' do
    hash = mapper.call('senec/0/ENERGY/GUI_GRID_POW', '-123.45')

    expect(hash).to eq({ 'grid_power_plus' => 0, 'grid_power_minus' => 123 })
  end

  it 'maps grid_power_plus with flipping' do
    other_config =
      ClimateControl.modify(VALID_ENV.merge(MQTT_FLIP_GRID_POW: 'true')) do
        Config.from_env
      end

    hash =
      mapper(config: other_config).call(
        'senec/0/ENERGY/GUI_GRID_POW',
        '-123.45',
      )

    expect(hash).to eq({ 'grid_power_minus' => 0, 'grid_power_plus' => 123 })
  end

  it 'maps current_state' do
    hash = mapper.call('senec/0/ENERGY/STAT_STATE_Text', 'LOADING')

    expect(hash).to eq({ 'current_state' => 'LOADING' })
  end

  it 'maps current_state_ok with true' do
    %w[true 1 OK].each do |value|
      hash = mapper.call('somewhere/STAT_STATE_OK', value)

      expect(hash).to eq({ 'current_state_ok' => true })
    end
  end

  it 'maps current_state_ok with false' do
    hash = mapper.call('somewhere/STAT_STATE_OK', '0')

    expect(hash).to eq({ 'current_state_ok' => false })
  end

  it 'maps case_temp' do
    hash = mapper.call('senec/0/TEMPMEASURE/CASE_TEMP', '35.2')

    expect(hash).to eq({ 'case_temp' => 35.2 })
  end

  it 'maps power_ratio' do
    hash = mapper.call('senec/0/PV1/POWER_RATIO', '70')

    expect(hash).to eq({ 'power_ratio' => 70 })
  end

  it 'maps heatpump_power' do
    hash = mapper.call('somewhere/HEATPUMP/POWER', '123.45')

    expect(hash).to eq({ 'heatpump_power' => 123 })
  end

  it 'raises on unknown topic' do
    expect do
      mapper.call('this/is/an/unknown/topic', 'foo!')
    end.to raise_error(RuntimeError)
  end
end
