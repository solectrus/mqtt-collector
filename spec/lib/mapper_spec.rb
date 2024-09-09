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
  'MAPPING_0_MIN' => '5',
  'MAPPING_0_MAX' => '15000',
  #
  'MAPPING_1_TOPIC' => 'senec/0/ENERGY/GUI_HOUSE_POW',
  'MAPPING_1_MEASUREMENT' => 'PV',
  'MAPPING_1_FIELD' => 'house_power',
  'MAPPING_1_TYPE' => 'integer',
  #
  'MAPPING_2_TOPIC' => 'senec/0/ENERGY/GUI_GRID_POW',
  'MAPPING_2_MEASUREMENT_POSITIVE' => 'PV',
  'MAPPING_2_MEASUREMENT_NEGATIVE' => 'PV',
  'MAPPING_2_FIELD_POSITIVE' => 'grid_import_power',
  'MAPPING_2_FIELD_NEGATIVE' => 'grid_export_power',
  'MAPPING_2_TYPE' => 'integer',
  #
  'MAPPING_3_TOPIC' => 'senec/0/PV1/POWER_RATIO',
  'MAPPING_3_MEASUREMENT' => 'PV',
  'MAPPING_3_FIELD' => 'grid_export_limit',
  'MAPPING_3_TYPE' => 'float',
  #
  'MAPPING_4_TOPIC' => 'senec/0/ENERGY/GUI_BAT_DATA_POWER',
  'MAPPING_4_MEASUREMENT_POSITIVE' => 'PV',
  'MAPPING_4_MEASUREMENT_NEGATIVE' => 'PV',
  'MAPPING_4_FIELD_POSITIVE' => 'battery_charging_power',
  'MAPPING_4_FIELD_NEGATIVE' => 'battery_discharging_power',
  'MAPPING_4_TYPE' => 'float',
  #
  'MAPPING_5_TOPIC' => 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE',
  'MAPPING_5_MEASUREMENT' => 'PV',
  'MAPPING_5_FIELD' => 'battery_soc',
  'MAPPING_5_TYPE' => 'float',
  #
  'MAPPING_6_TOPIC' => 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
  'MAPPING_6_MEASUREMENT' => 'PV',
  'MAPPING_6_FIELD' => 'wallbox_power0',
  'MAPPING_6_TYPE' => 'integer',
  #
  'MAPPING_7_TOPIC' => 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/1',
  'MAPPING_7_MEASUREMENT' => 'PV',
  'MAPPING_7_FIELD' => 'wallbox_power1',
  'MAPPING_7_TYPE' => 'integer',
  #
  'MAPPING_8_TOPIC' => 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/2',
  'MAPPING_8_MEASUREMENT' => 'PV',
  'MAPPING_8_FIELD' => 'wallbox_power2',
  'MAPPING_8_TYPE' => 'integer',
  #
  'MAPPING_9_TOPIC' => 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/3',
  'MAPPING_9_MEASUREMENT' => 'PV',
  'MAPPING_9_FIELD' => 'wallbox_power3',
  'MAPPING_9_TYPE' => 'integer',
  #
  'MAPPING_10_TOPIC' => 'somewhere/HEATPUMP/POWER',
  'MAPPING_10_MEASUREMENT' => 'HEATPUMP',
  'MAPPING_10_FIELD' => 'power',
  'MAPPING_10_TYPE' => 'integer',
  #
  'MAPPING_11_TOPIC' => 'senec/0/TEMPMEASURE/CASE_TEMP',
  'MAPPING_11_MEASUREMENT' => 'PV',
  'MAPPING_11_FIELD' => 'case_temp',
  'MAPPING_11_TYPE' => 'float',
  #
  'MAPPING_12_TOPIC' => 'senec/0/ENERGY/STAT_STATE_Text',
  'MAPPING_12_MEASUREMENT' => 'PV',
  'MAPPING_12_FIELD' => 'system_status',
  'MAPPING_12_TYPE' => 'string',
  #
  'MAPPING_13_TOPIC' => 'senec/0/PV1/MPP_POWER/0',
  'MAPPING_13_MEASUREMENT' => 'PV',
  'MAPPING_13_FIELD' => 'mpp1_power',
  'MAPPING_13_TYPE' => 'integer',
  #
  'MAPPING_14_TOPIC' => 'senec/0/PV1/MPP_POWER/1',
  'MAPPING_14_MEASUREMENT' => 'PV',
  'MAPPING_14_FIELD' => 'mpp2_power',
  'MAPPING_14_TYPE' => 'integer',
  #
  'MAPPING_15_TOPIC' => 'senec/0/PV1/MPP_POWER/2',
  'MAPPING_15_MEASUREMENT' => 'PV',
  'MAPPING_15_FIELD' => 'mpp3_power',
  'MAPPING_15_TYPE' => 'integer',
  #
  'MAPPING_16_TOPIC' => 'somewhere/STAT_STATE_OK',
  'MAPPING_16_MEASUREMENT' => 'PV',
  'MAPPING_16_FIELD' => 'system_status_ok',
  'MAPPING_16_TYPE' => 'boolean',
  #
  'MAPPING_17_TOPIC' => 'somewhere/ATTR',
  'MAPPING_17_JSON_KEY' => 'leaving_temp',
  'MAPPING_17_MEASUREMENT' => 'HEATPUMP',
  'MAPPING_17_FIELD' => 'leaving_temp',
  'MAPPING_17_TYPE' => 'float',
  #
  'MAPPING_18_TOPIC' => 'somewhere/ATTR',
  'MAPPING_18_JSON_KEY' => 'inlet_temp',
  'MAPPING_18_MEASUREMENT' => 'HEATPUMP',
  'MAPPING_18_FIELD' => 'inlet_temp',
  'MAPPING_18_TYPE' => 'float',
  #
  'MAPPING_19_TOPIC' => 'somewhere/ATTR',
  'MAPPING_19_JSON_KEY' => 'water_flow',
  'MAPPING_19_MEASUREMENT' => 'HEATPUMP',
  'MAPPING_19_FIELD' => 'water_flow',
  'MAPPING_19_TYPE' => 'float',
  #
  'MAPPING_20_TOPIC' => 'somewhere/ATTR',
  'MAPPING_20_JSON_FORMULA' => '{$.leaving_temp} - {$.inlet_temp}',
  'MAPPING_20_MEASUREMENT' => 'HEATPUMP',
  'MAPPING_20_FIELD' => 'temp_diff',
  'MAPPING_20_TYPE' => 'float',
  #
  'MAPPING_21_TOPIC' => 'somewhere/ATTR',
  'MAPPING_21_JSON_FORMULA' =>
    'round({water_flow} * 60.0 * 1.163 * ({leaving_temp} - {inlet_temp}))',
  'MAPPING_21_MEASUREMENT' => 'HEATPUMP',
  'MAPPING_21_FIELD' => 'heat',
  'MAPPING_21_TYPE' => 'float',
  #
  'MAPPING_22_TOPIC' => 'go-e/ATTR',
  'MAPPING_22_JSON_PATH' => '$.ccp[6]',
  'MAPPING_22_MEASUREMENT' => 'WALLBOX',
  'MAPPING_22_FIELD' => 'power',
  'MAPPING_22_TYPE' => 'float',
}.freeze

EXPECTED_TOPICS = %w[
  go-e/ATTR
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
  somewhere/ATTR
  somewhere/HEATPUMP/POWER
  somewhere/STAT_STATE_OK
].freeze

describe Mapper do
  subject(:mapper) { described_class.new(config:) }

  let(:config) { Config.new(VALID_ENV, logger:) }
  let(:logger) { MemoryLogger.new }

  it 'has topics' do
    expect(mapper.topics).to eq(EXPECTED_TOPICS)
  end

  it 'formats mapping' do
    expect(mapper.formatted_mapping('senec/0/ENERGY/GUI_INVERTER_POWER')).to eq(
      'PV:inverter_power (5 ≥ integer ≤ 15000)',
    )

    expect(
      mapper.formatted_mapping('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE'),
    ).to eq('PV:battery_soc (float)')

    expect(
      mapper.formatted_mapping('go-e/ATTR'),
    ).to eq('WALLBOX:power (float)')
  end

  it 'formats mapping with sign' do
    expect(mapper.formatted_mapping('senec/0/ENERGY/GUI_GRID_POW')).to eq(
      'PV:grid_import_power (+) PV:grid_export_power (-) (integer)',
    )
  end

  it 'formats mapping with multiple keys' do
    expect(mapper.formatted_mapping('somewhere/ATTR')).to eq(
      'HEATPUMP:leaving_temp (float), ' \
      'HEATPUMP:inlet_temp (float), ' \
      'HEATPUMP:water_flow (float), ' \
      'HEATPUMP:temp_diff (float), ' \
      'HEATPUMP:heat (float)',
    )
  end

  it 'maps inverter power' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', '123.45')

    expect(hash).to eq(
      [{ field: 'inverter_power', measurement: 'PV', value: 123 }],
    )
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

    expect(hash).to eq(
      [{ field: 'house_power', measurement: 'PV', value: 123 }],
    )
  end

  it 'maps bat_fuel_charge' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE', '80.5')

    expect(hash).to eq(
      [{ field: 'battery_soc', measurement: 'PV', value: 80.5 }],
    )
  end

  it 'maps wallbox_charge_power' do
    hash =
      mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/0', '123.45')

    expect(hash).to eq(
      [{ field: 'wallbox_power0', measurement: 'PV', value: 123 }],
    )
  end

  it 'maps wallbox_charge_power1' do
    hash =
      mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/1', '123.45')

    expect(hash).to eq(
      [{ field: 'wallbox_power1', measurement: 'PV', value: 123 }],
    )
  end

  it 'maps wallbox_charge_power2' do
    hash =
      mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/2', '123.45')

    expect(hash).to eq(
      [{ field: 'wallbox_power2', measurement: 'PV', value: 123 }],
    )
  end

  it 'maps wallbox_charge_power3' do
    hash =
      mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/3', '123.45')

    expect(hash).to eq(
      [{ field: 'wallbox_power3', measurement: 'PV', value: 123 }],
    )
  end

  it 'maps battery_charging_power' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_BAT_DATA_POWER', '123.45')

    expect(hash).to eq(
      [
        { field: 'battery_discharging_power', measurement: 'PV', value: 0.0 },
        { field: 'battery_charging_power', measurement: 'PV', value: 123.45 },
      ],
    )

    expect(hash).to all(include(value: a_kind_of(Float)))
  end

  it 'maps bat_power' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_BAT_DATA_POWER', '-123.45')

    expect(hash).to eq(
      [
        { field: 'battery_discharging_power', measurement: 'PV', value: 123.45 },
        { field: 'battery_charging_power', measurement: 'PV', value: 0.0 },
      ],
    )

    expect(hash).to all(include(value: a_kind_of(Float)))
  end

  it 'maps grid_power_plus' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_GRID_POW', '123.45')

    expect(hash).to eq(
      [
        { field: 'grid_export_power', measurement: 'PV', value: 0 },
        { field: 'grid_import_power', measurement: 'PV', value: 123 },
      ],
    )

    expect(hash).to all(include(value: a_kind_of(Integer)))
  end

  it 'maps grid_power_minus' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_GRID_POW', '-123.45')

    expect(hash).to eq(
      [
        { field: 'grid_export_power', measurement: 'PV', value: 123 },
        { field: 'grid_import_power', measurement: 'PV', value: 0 },
      ],
    )

    expect(hash).to all(include(value: a_kind_of(Integer)))
  end

  it 'maps current_state' do
    hash = mapper.records_for('senec/0/ENERGY/STAT_STATE_Text', 'LOADING')

    expect(hash).to eq(
      [{ field: 'system_status', measurement: 'PV', value: 'LOADING' }],
    )
  end

  it 'maps current_state_ok with true' do
    %w[true TRUE].each do |value|
      hash = mapper.records_for('somewhere/STAT_STATE_OK', value)

      expect(hash).to eq(
        [{ field: 'system_status_ok', measurement: 'PV', value: true }],
      )
    end
  end

  it 'maps current_state_ok with false' do
    %w[false FALSE].each do |value|
      hash = mapper.records_for('somewhere/STAT_STATE_OK', value)

      expect(hash).to eq(
        [{ field: 'system_status_ok', measurement: 'PV', value: false }],
      )
    end
  end

  it 'maps case_temp' do
    hash = mapper.records_for('senec/0/TEMPMEASURE/CASE_TEMP', '35.2')

    expect(hash).to eq([{ field: 'case_temp', measurement: 'PV', value: 35.2 }])
  end

  it 'maps power_ratio' do
    hash = mapper.records_for('senec/0/PV1/POWER_RATIO', '0')

    expect(hash).to eq(
      [{ field: 'grid_export_limit', measurement: 'PV', value: 0 }],
    )
  end

  it 'maps heatpump_power' do
    hash = mapper.records_for('somewhere/HEATPUMP/POWER', '123.45')

    expect(hash).to eq(
      [{ field: 'power', measurement: 'HEATPUMP', value: 123 }],
    )
  end

  it 'maps with JSON_PATH' do
    hash = mapper.records_for(
      'go-e/ATTR',
      '{"ccp": [103.5098,-9787.971,null,null,10072.18,-180.701,3.295279,100.2145,null,null,null,null,null,null,null,null]}',
    )

    expect(hash).to eq([{ field: 'power', measurement: 'WALLBOX', value: 3.295279 }])
  end

  it 'maps json and calculates formula' do
    hash =
      mapper.records_for(
        'somewhere/ATTR',
        '{"leaving_temp": 35.2, "inlet_temp": 20.5, "water_flow": 16.45}',
      )

    expect(hash).to eq(
      [
        { measurement: 'HEATPUMP', field: 'leaving_temp', value: 35.2 },
        { measurement: 'HEATPUMP', field: 'inlet_temp',   value: 20.5 },
        { measurement: 'HEATPUMP', field: 'water_flow',   value: 16.45 },
        { measurement: 'HEATPUMP', field: 'temp_diff',    value: 14.7 },   # 35.2 - 20.5
        { measurement: 'HEATPUMP', field: 'heat',         value: 16_874 }, # (16.45 * 60 * 1.163 * (20.5 - 35.2)).round
      ],
    )
  end

  it 'maps NULL to 0' do
    hash =
      mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/0', nil)

    expect(hash).to eq(
      [{ field: 'wallbox_power0', measurement: 'PV', value: 0 }],
    )
  end

  it 'handles invalid JSON' do
    hash = mapper.records_for('somewhere/ATTR', 'this is not JSON')

    expect(logger.warn_messages).to include(/Failed to parse JSON/)
    expect(hash).to eq(
      [
        { field: 'leaving_temp', measurement: 'HEATPUMP', value: 0.0 },
        { field: 'inlet_temp', measurement: 'HEATPUMP', value: 0.0 },
        { field: 'water_flow', measurement: 'HEATPUMP', value: 0.0 },
        { field: 'temp_diff', measurement: 'HEATPUMP', value: 0.0 },
        { field: 'heat', measurement: 'HEATPUMP', value: 0.0 },
      ],
    )
  end

  it 'handles invalid value types' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', {})
    expect(hash).to eq([])

    hash = mapper.records_for('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE', :foo)
    expect(hash).to eq([])
  end

  it 'handles value < minimum' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', '-10')

    expect(hash).to eq(
      [],
    )
    expect(logger.warn_messages).to include(/Ignoring inverter_power: -10 is below minimum of 5/)
  end

  it 'handles value > maximum' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', '16000')

    expect(hash).to eq(
      [],
    )
    expect(logger.warn_messages).to include(/Ignoring inverter_power: 16000 exceeds maximum of 15000/)
  end

  it 'raises on unknown topic' do
    expect do
      mapper.records_for('this/is/an/unknown/topic', 'foo!')
    end.to raise_error(RuntimeError)
  end
end
