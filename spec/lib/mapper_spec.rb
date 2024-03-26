require 'mapper'
require 'config'

VALID_ENV = {
  'MQTT_HOST' => '1.2.3.4',
  'MQTT_PORT' => '1883',
  'MQTT_USERNAME' => 'username',
  'MQTT_PASSWORD' => 'password',
  'MQTT_SSL' => 'false',
  # ---
  'INFLUX_HOST' => 'influx.example.com',
  'INFLUX_SCHEMA' => 'https',
  'INFLUX_PORT' => '443',
  'INFLUX_TOKEN' => 'this.is.just.an.example',
  'INFLUX_ORG' => 'solectrus',
  'INFLUX_BUCKET' => 'my-bucket',
  # ---
  'MAPPING_0_TOPIC' => 'senec/0/ENERGY/GUI_INVERTER_POWER',
  'MAPPING_0_MEASUREMENT' => 'PV',
  'MAPPING_0_FIELD' => 'inverter_power',
  'MAPPING_0_TYPE' => 'integer',

  'MAPPING_1_TOPIC' => 'senec/0/ENERGY/GUI_HOUSE_POW',
  'MAPPING_1_MEASUREMENT' => 'PV',
  'MAPPING_1_FIELD' => 'house_power',
  'MAPPING_1_TYPE' => 'integer',

  'MAPPING_2_TOPIC' => 'senec/0/ENERGY/GUI_GRID_POW',
  'MAPPING_2_MEASUREMENT_POSITIVE' => 'PV',
  'MAPPING_2_MEASUREMENT_NEGATIVE' => 'PV',
  'MAPPING_2_FIELD_POSITIVE' => 'grid_import_power',
  'MAPPING_2_FIELD_NEGATIVE' => 'grid_export_power',
  'MAPPING_2_TYPE' => 'integer',

  'MAPPING_3_TOPIC' => 'senec/0/PV1/POWER_RATIO',
  'MAPPING_3_MEASUREMENT' => 'PV',
  'MAPPING_3_FIELD' => 'grid_export_limit',
  'MAPPING_3_TYPE' => 'float',

  'MAPPING_4_TOPIC' => 'senec/0/ENERGY/GUI_BAT_DATA_POWER',
  'MAPPING_4_MEASUREMENT_POSITIVE' => 'PV',
  'MAPPING_4_MEASUREMENT_NEGATIVE' => 'PV',
  'MAPPING_4_FIELD_POSITIVE' => 'battery_charging_power',
  'MAPPING_4_FIELD_NEGATIVE' => 'battery_discharging_power',
  'MAPPING_4_TYPE' => 'integer',

  'MAPPING_5_TOPIC' => 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE',
  'MAPPING_5_MEASUREMENT' => 'PV',
  'MAPPING_5_FIELD' => 'battery_soc',
  'MAPPING_5_TYPE' => 'float',

  'MAPPING_6_TOPIC' => 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
  'MAPPING_6_MEASUREMENT' => 'PV',
  'MAPPING_6_FIELD' => 'wallbox_power0',
  'MAPPING_6_TYPE' => 'integer',

  'MAPPING_7_TOPIC' => 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/1',
  'MAPPING_7_MEASUREMENT' => 'PV',
  'MAPPING_7_FIELD' => 'wallbox_power1',
  'MAPPING_7_TYPE' => 'integer',

  'MAPPING_8_TOPIC' => 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/2',
  'MAPPING_8_MEASUREMENT' => 'PV',
  'MAPPING_8_FIELD' => 'wallbox_power2',
  'MAPPING_8_TYPE' => 'integer',

  'MAPPING_9_TOPIC' => 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/3',
  'MAPPING_9_MEASUREMENT' => 'PV',
  'MAPPING_9_FIELD' => 'wallbox_power3',
  'MAPPING_9_TYPE' => 'integer',

  'MAPPING_10_TOPIC' => 'somewhere/HEATPUMP/POWER',
  'MAPPING_10_MEASUREMENT' => 'HEATPUMP',
  'MAPPING_10_FIELD' => 'power',
  'MAPPING_10_TYPE' => 'integer',

  'MAPPING_11_TOPIC' => 'senec/0/TEMPMEASURE/CASE_TEMP',
  'MAPPING_11_MEASUREMENT' => 'PV',
  'MAPPING_11_FIELD' => 'case_temp',
  'MAPPING_11_TYPE' => 'float',

  'MAPPING_12_TOPIC' => 'senec/0/ENERGY/STAT_STATE_Text',
  'MAPPING_12_MEASUREMENT' => 'PV',
  'MAPPING_12_FIELD' => 'system_status',
  'MAPPING_12_TYPE' => 'string',

  'MAPPING_13_FIELD' => 'mpp1_power',
  'MAPPING_13_MEASUREMENT' => 'PV',
  'MAPPING_13_TOPIC' => 'senec/0/PV1/MPP_POWER/0',
  'MAPPING_13_TYPE' => 'integer',

  'MAPPING_14_FIELD' => 'mpp2_power',
  'MAPPING_14_MEASUREMENT' => 'PV',
  'MAPPING_14_TOPIC' => 'senec/0/PV1/MPP_POWER/1',
  'MAPPING_14_TYPE' => 'integer',

  'MAPPING_15_FIELD' => 'mpp3_power',
  'MAPPING_15_MEASUREMENT' => 'PV',
  'MAPPING_15_TOPIC' => 'senec/0/PV1/MPP_POWER/2',
  'MAPPING_15_TYPE' => 'integer',

  'MAPPING_16_FIELD' => 'system_status_ok',
  'MAPPING_16_MEASUREMENT' => 'PV',
  'MAPPING_16_TOPIC' => 'somewhere/STAT_STATE_OK',
  'MAPPING_16_TYPE' => 'boolean',
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
    @default_config ||= Config.new(VALID_ENV)
  end

  def mapper(config: nil)
    Mapper.new(config: config || default_config)
  end

  it 'has topics' do
    expect(mapper.topics).to eq(EXPECTED_TOPICS)
  end

  it 'formats mapping' do
    expect(mapper.formatted_mapping('senec/0/ENERGY/GUI_INVERTER_POWER')).to eq(
      'PV:inverter_power (integer)',
    )

    expect(mapper.formatted_mapping('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE')).to eq(
      'PV:battery_soc (float)',
    )

    expect(mapper.formatted_mapping('senec/0/ENERGY/GUI_GRID_POW')).to eq(
      'PV:grid_import_power (+) PV:grid_export_power (-) (integer)',
    )
  end

  it 'maps inverter power' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', '123.45')

    expect(hash).to eq([{ field: 'inverter_power', measurement: 'PV', value: 123 }])
  end

  it 'maps mpp1_power' do
    hash = mapper.records_for('senec/0/PV1/MPP_POWER/0', '123.45')

    expect(hash).to eq([{ field: 'mpp1_power', measurement: 'PV', value: 123 }])
  end

  it 'maps mpp2_power' do
    hash = mapper.records_for('senec/0/PV1/MPP_POWER/1', '123.45')

    expect(hash).to eq([{ field: 'mpp2_power', measurement: 'PV', value: 123 }])
  end

  it 'maps mpp3_power' do
    hash = mapper.records_for('senec/0/PV1/MPP_POWER/2', '123.45')

    expect(hash).to eq([{ field: 'mpp3_power', measurement: 'PV', value: 123 }])
  end

  it 'maps house_power' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_HOUSE_POW', '123.45')

    expect(hash).to eq([{ field: 'house_power', measurement: 'PV', value: 123 }])
  end

  it 'maps bat_fuel_charge' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE', '80.5')

    expect(hash).to eq([{ field: 'battery_soc', measurement: 'PV', value: 80.5 }])
  end

  it 'maps wallbox_charge_power' do
    hash = mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/0', '123.45')

    expect(hash).to eq([{ field: 'wallbox_power0', measurement: 'PV', value: 123 }])
  end

  it 'maps wallbox_charge_power1' do
    hash = mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/1', '123.45')

    expect(hash).to eq([{ field: 'wallbox_power1', measurement: 'PV', value: 123 }])
  end

  it 'maps wallbox_charge_power2' do
    hash = mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/2', '123.45')

    expect(hash).to eq([{ field: 'wallbox_power2', measurement: 'PV', value: 123 }])
  end

  it 'maps wallbox_charge_power3' do
    hash = mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/3', '123.45')

    expect(hash).to eq([{ field: 'wallbox_power3', measurement: 'PV', value: 123 }])
  end

  it 'maps battery_charging_power' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_BAT_DATA_POWER', '123.45')

    expect(hash).to eq(
      [
        { field: 'battery_discharging_power',
          measurement: 'PV',
          value: 0, },
        { field: 'battery_charging_power', measurement: 'PV', value: 123 },
      ],
    )
  end

  it 'maps bat_power' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_BAT_DATA_POWER', '-123.45')

    expect(hash).to eq(
      [
        { field: 'battery_discharging_power',
          measurement: 'PV',
          value: 123, },
        { field: 'battery_charging_power', measurement: 'PV', value: 0 },
      ],
    )
  end

  it 'maps grid_power_plus' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_GRID_POW', '123.45')

    expect(hash).to eq(
      [{ field: 'grid_export_power', measurement: 'PV', value: 0 },
       { field: 'grid_import_power', measurement: 'PV', value: 123 },],
    )
  end

  it 'maps grid_power_minus' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_GRID_POW', '-123.45')

    expect(hash).to eq(
      [{ field: 'grid_export_power', measurement: 'PV', value: 123 },
       { field: 'grid_import_power', measurement: 'PV', value: 0 },],
    )
  end

  it 'maps current_state' do
    hash = mapper.records_for('senec/0/ENERGY/STAT_STATE_Text', 'LOADING')

    expect(hash).to eq([{ field: 'system_status', measurement: 'PV', value: 'LOADING' }])
  end

  it 'maps current_state_ok with true' do
    %w[true TRUE].each do |value|
      hash = mapper.records_for('somewhere/STAT_STATE_OK', value)

      expect(hash).to eq([{ field: 'system_status_ok', measurement: 'PV', value: true }])
    end
  end

  it 'maps current_state_ok with false' do
    %w[false FALSE].each do |value|
      hash = mapper.records_for('somewhere/STAT_STATE_OK', value)

      expect(hash).to eq([{ field: 'system_status_ok', measurement: 'PV', value: false }])
    end
  end

  it 'maps case_temp' do
    hash = mapper.records_for('senec/0/TEMPMEASURE/CASE_TEMP', '35.2')

    expect(hash).to eq([{ field: 'case_temp', measurement: 'PV', value: 35.2 }])
  end

  it 'maps power_ratio' do
    hash = mapper.records_for('senec/0/PV1/POWER_RATIO', '0')

    expect(hash).to eq([{ field: 'grid_export_limit', measurement: 'PV', value: 0 }])
  end

  it 'maps heatpump_power' do
    hash = mapper.records_for('somewhere/HEATPUMP/POWER', '123.45')

    expect(hash).to eq([{ field: 'power', measurement: 'HEATPUMP', value: 123 }])
  end

  it 'handles invalid value types' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', {})
    expect(hash).to eq([{ field: 'inverter_power', measurement: 'PV', value: nil }])

    hash = mapper.records_for('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE', {})
    expect(hash).to eq([{ field: 'battery_soc', measurement: 'PV', value: nil }])
  end

  it 'raises on unknown topic' do
    expect do
      mapper.records_for('this/is/an/unknown/topic', 'foo!')
    end.to raise_error(RuntimeError)
  end
end
