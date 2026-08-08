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
  'MAPPING_22_NULL_TO_ZERO' => 'true',
  #
  'MAPPING_23_TOPIC' => 'somewhere/power-kwh',
  'MAPPING_23_FORMULA' => '{value} * 1000',
  'MAPPING_23_MEASUREMENT' => 'Consumer',
  'MAPPING_23_FIELD' => 'power',
  'MAPPING_23_TYPE' => 'float',
  #
  'MAPPING_24_TOPIC' => 'somewhere/power-negative',
  'MAPPING_24_FORMULA' => 'abs({value})',
  'MAPPING_24_MEASUREMENT' => 'PV',
  'MAPPING_24_FIELD' => 'inverter_power',
  'MAPPING_24_TYPE' => 'integer',
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
  somewhere/power-kwh
  somewhere/power-negative
].freeze

VIRTUAL_ENV = {
  'MQTT_HOST' => '1.2.3.4',
  'MQTT_PORT' => '1883',
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
  'MAPPING_0_NAME' => 'inverter_power',
  #
  'MAPPING_1_TOPIC' => 'senec/0/ENERGY/GUI_HOUSE_POW',
  'MAPPING_1_MEASUREMENT' => 'PV',
  'MAPPING_1_FIELD' => 'house_power',
  'MAPPING_1_TYPE' => 'integer',
  'MAPPING_1_NAME' => 'house_power',
  #
  # Virtual mapping: no topic, calculated from inverter_power and house_power
  'MAPPING_2_MEASUREMENT' => 'PV',
  'MAPPING_2_FIELD' => 'total_power',
  'MAPPING_2_TYPE' => 'integer',
  'MAPPING_2_FORMULA' => '{inverter_power} + {house_power}',
  #
  # Virtual mapping: no topic, referencing a name that's never defined anywhere
  'MAPPING_3_MEASUREMENT' => 'PV',
  'MAPPING_3_FIELD' => 'missing_ref',
  'MAPPING_3_TYPE' => 'integer',
  'MAPPING_3_NULL_TO_ZERO' => 'true',
  'MAPPING_3_FORMULA' => '{missing_sensor}',
  #
  # Virtual mapping: no topic, with positive/negative fields
  'MAPPING_4_MEASUREMENT_POSITIVE' => 'PV',
  'MAPPING_4_MEASUREMENT_NEGATIVE' => 'PV',
  'MAPPING_4_FIELD_POSITIVE' => 'net_power_plus',
  'MAPPING_4_FIELD_NEGATIVE' => 'net_power_minus',
  'MAPPING_4_TYPE' => 'integer',
  'MAPPING_4_FORMULA' => '{inverter_power} - {house_power}',
}.freeze

MAX_AGE_ENV = {
  'MQTT_HOST' => '1.2.3.4',
  'MQTT_PORT' => '1883',
  # ---
  'INFLUX_HOST' => 'influx.example.com',
  'INFLUX_SCHEMA' => 'https',
  'INFLUX_PORT' => '443',
  'INFLUX_TOKEN' => 'this.is.just.an.example',
  'INFLUX_ORG' => 'solectrus',
  'INFLUX_BUCKET' => 'my-bucket',
  # ---
  'MAPPING_0_TOPIC' => 'sensor/power',
  'MAPPING_0_MEASUREMENT' => 'PV',
  'MAPPING_0_FIELD' => 'power',
  'MAPPING_0_TYPE' => 'integer',
  'MAPPING_0_NAME' => 'power',
  'MAPPING_0_MAX_AGE' => '30',
  #
  'MAPPING_1_TOPIC' => 'sensor/other',
  'MAPPING_1_MEASUREMENT' => 'PV',
  'MAPPING_1_FIELD' => 'other',
  'MAPPING_1_TYPE' => 'integer',
  'MAPPING_1_NAME' => 'other',
  #
  # Virtual mapping: no topic, calculated from power and other
  'MAPPING_2_MEASUREMENT' => 'PV',
  'MAPPING_2_FIELD' => 'shadow_power',
  'MAPPING_2_TYPE' => 'integer',
  'MAPPING_2_FORMULA' => '{power} + {other}',
  #
  # Unrelated topic, only used to trigger a virtual mapping recalculation
  'MAPPING_3_TOPIC' => 'sensor/decoy',
  'MAPPING_3_MEASUREMENT' => 'PV',
  'MAPPING_3_FIELD' => 'decoy',
  'MAPPING_3_TYPE' => 'integer',
}.freeze

LOGIC_ENV = {
  'MQTT_HOST' => '1.2.3.4',
  'MQTT_PORT' => '1883',
  # ---
  'INFLUX_HOST' => 'influx.example.com',
  'INFLUX_SCHEMA' => 'https',
  'INFLUX_PORT' => '443',
  'INFLUX_TOKEN' => 'this.is.just.an.example',
  'INFLUX_ORG' => 'solectrus',
  'INFLUX_BUCKET' => 'my-bucket',
  # ---
  'MAPPING_0_TOPIC' => 'sensor/x',
  'MAPPING_0_MEASUREMENT' => 'PV',
  'MAPPING_0_FIELD' => 'x',
  'MAPPING_0_TYPE' => 'integer',
  'MAPPING_0_NAME' => 'x',
  #
  'MAPPING_1_TOPIC' => 'sensor/y',
  'MAPPING_1_MEASUREMENT' => 'PV',
  'MAPPING_1_FIELD' => 'y',
  'MAPPING_1_TYPE' => 'integer',
  'MAPPING_1_NAME' => 'y',
  #
  # Virtual mapping: no topic, uses IF() with a comparison across mappings
  'MAPPING_2_MEASUREMENT' => 'PV',
  'MAPPING_2_FIELD' => 'different',
  'MAPPING_2_TYPE' => 'integer',
  'MAPPING_2_FORMULA' => 'IF({x} != {y}, {x}, 0)',
}.freeze

AGGREGATE_ENV = {
  'MQTT_HOST' => '1.2.3.4',
  'MQTT_PORT' => '1883',
  # ---
  'INFLUX_HOST' => 'influx.example.com',
  'INFLUX_SCHEMA' => 'https',
  'INFLUX_PORT' => '443',
  'INFLUX_TOKEN' => 'this.is.just.an.example',
  'INFLUX_ORG' => 'solectrus',
  'INFLUX_BUCKET' => 'my-bucket',
  # ---
  'MAPPING_0_TOPIC' => 'sensor/fast',
  'MAPPING_0_MEASUREMENT' => 'PV',
  'MAPPING_0_FIELD' => 'fast_value',
  'MAPPING_0_TYPE' => 'integer',
  'MAPPING_0_AGGREGATE_INTERVAL' => '5',
  #
  'MAPPING_1_TOPIC' => 'sensor/plain',
  'MAPPING_1_MEASUREMENT' => 'PV',
  'MAPPING_1_FIELD' => 'plain_value',
  'MAPPING_1_TYPE' => 'integer',
  #
  'MAPPING_2_TOPIC' => 'sensor/signed',
  'MAPPING_2_MEASUREMENT_POSITIVE' => 'PV',
  'MAPPING_2_MEASUREMENT_NEGATIVE' => 'PV',
  'MAPPING_2_FIELD_POSITIVE' => 'signed_plus',
  'MAPPING_2_FIELD_NEGATIVE' => 'signed_minus',
  'MAPPING_2_TYPE' => 'integer',
  'MAPPING_2_AGGREGATE_INTERVAL' => '5',
}.freeze

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
    ).to eq('WALLBOX:power (float, converting NULL to 0)')
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

  it 'ignores missing value for mappings with sign handling' do
    hash = mapper.records_for('senec/0/ENERGY/GUI_GRID_POW', '')

    expect(hash).to eq(
      [],
    )
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

  it 'maps plain value and calculates formula' do
    hash = mapper.records_for('somewhere/power-kwh', '123.45')

    expect(hash).to eq(
      [
        { measurement: 'Consumer', field: 'power', value: 123_450 },
      ],
    )
  end

  it 'maps plain negative value with abs() formula' do
    hash = mapper.records_for('somewhere/power-negative', '-500')

    expect(hash).to eq(
      [
        { measurement: 'PV', field: 'inverter_power', value: 500 },
      ],
    )
  end

  it 'converts NULL to 0 (because NULL_TO_ZERO is "true")' do
    hash =
      mapper.records_for(
        'go-e/ATTR',
        '{"ccp": [103.5098,-9787.971,null,null,10072.18,-180.701,null,100.2145,null,null,null,null,null,null,null,null]}',
      )

    expect(hash).to eq(
      [{ field: 'power', measurement: 'WALLBOX', value: 0 }],
    )
  end

  it 'ignores NULL value (because NULL_TO_ZERO is not set)' do
    hash =
      mapper.records_for('senec/0/WALLBOX/APPARENT_CHARGING_POWER/1', nil)

    expect(hash).to eq(
      [],
    )
  end

  it 'handles invalid JSON' do
    hash = mapper.records_for('somewhere/ATTR', 'this is not JSON')

    expect(logger.warn_messages).to include(/Failed to parse JSON/)
    expect(hash).to eq(
      [],
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

  context 'with virtual mappings' do
    subject(:mapper) { described_class.new(config:) }

    let(:config) { Config.new(VIRTUAL_ENV, logger:) }
    let(:logger) { MemoryLogger.new }

    it 'does not subscribe to a topic for virtual mappings' do
      expect(mapper.topics).to eq(
        %w[
          senec/0/ENERGY/GUI_HOUSE_POW
          senec/0/ENERGY/GUI_INVERTER_POWER
        ],
      )
    end

    it 'lists virtual mappings' do
      expect(mapper.virtual_mappings.map { |mapping| mapping[:mapping_group] }).to eq(
        %w[2 3 4],
      )
    end

    it 'formats a virtual mapping including its formula' do
      expect(mapper.formatted_virtual_mapping(mapper.virtual_mappings[0])).to eq(
        'PV:total_power (integer) = {inverter_power} + {house_power}',
      )

      expect(mapper.formatted_virtual_mapping(mapper.virtual_mappings[2])).to eq(
        'PV:net_power_plus (+) PV:net_power_minus (-) (integer) = {inverter_power} - {house_power}',
      )
    end

    it 'ignores the virtual mapping until all referenced values are known' do
      hash = mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', '1000')

      expect(hash).to eq(
        [
          { field: 'inverter_power', measurement: 'PV', value: 1000 },
          { field: 'missing_ref', measurement: 'PV', value: 0 },
        ],
      )
      expect(logger.warn_messages).to include(/Formula for total_power/)
      expect(logger.warn_messages).to include(/Formula for net_power_plus/)
    end

    it 'calculates the virtual mapping once all referenced values are known, and keeps it updated' do
      mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', '1000')

      hash = mapper.records_for('senec/0/ENERGY/GUI_HOUSE_POW', '600')
      expect(hash).to eq(
        [
          { field: 'house_power', measurement: 'PV', value: 600 },
          { field: 'total_power', measurement: 'PV', value: 1600 },
          { field: 'missing_ref', measurement: 'PV', value: 0 },
          { field: 'net_power_minus', measurement: 'PV', value: 0 },
          { field: 'net_power_plus', measurement: 'PV', value: 400 },
        ],
      )

      # A later update of just one referenced mapping recalculates the virtual mapping
      hash = mapper.records_for('senec/0/ENERGY/GUI_INVERTER_POWER', '2000')
      expect(hash).to eq(
        [
          { field: 'inverter_power', measurement: 'PV', value: 2000 },
          { field: 'total_power', measurement: 'PV', value: 2600 },
          { field: 'missing_ref', measurement: 'PV', value: 0 },
          { field: 'net_power_minus', measurement: 'PV', value: 0 },
          { field: 'net_power_plus', measurement: 'PV', value: 1400 },
        ],
      )
    end
  end

  context 'with MAPPING_X_MAX_AGE' do
    subject(:mapper) { described_class.new(config:) }

    let(:config) { Config.new(MAX_AGE_ENV, logger:) }
    let(:logger) { MemoryLogger.new }

    it 'still uses a value within MAX_AGE' do
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(1000.0)
      mapper.records_for('sensor/power', '100')

      # 10 seconds later - still within MAX_AGE of 30 seconds
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(1010.0)
      hash = mapper.records_for('sensor/other', '5')

      expect(hash).to eq(
        [
          { field: 'other', measurement: 'PV', value: 5 },
          { field: 'shadow_power', measurement: 'PV', value: 105 },
        ],
      )
    end

    it 'ignores a value beyond MAX_AGE, as if it was never received' do
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(1000.0)
      mapper.records_for('sensor/power', '100')

      # 31 seconds later - beyond MAX_AGE of 30 seconds
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(1031.0)
      hash = mapper.records_for('sensor/other', '5')

      expect(hash).to eq(
        [{ field: 'other', measurement: 'PV', value: 5 }],
      )
      expect(logger.warn_messages).to include(
        %r{Formula for shadow_power.*power \[sensor/power\]: last received 31s ago},
      )
      expect(logger.warn_messages).to include(/exceeds MAX_AGE of 30s/)
    end

    it 'names all missing or outdated references, not just the first one' do
      # Neither "power" nor "other" has ever received a value
      hash = mapper.records_for('sensor/decoy', '1')

      expect(hash).to eq(
        [{ field: 'decoy', measurement: 'PV', value: 1 }],
      )
      expect(logger.warn_messages).to include(
        %r{Formula for shadow_power.*power \[sensor/power\]: never received.*other \[sensor/other\]: never received},
      )
    end
  end

  context 'with a comparison operator (==, !=) in a virtual mapping formula' do
    subject(:mapper) { described_class.new(config:) }

    let(:config) { Config.new(LOGIC_ENV, logger:) }
    let(:logger) { MemoryLogger.new }

    it 'does not calculate the result before both sides are known' do
      hash = mapper.records_for('sensor/x', '10')

      expect(hash).to eq([{ field: 'x', measurement: 'PV', value: 10 }])
    end

    it 'returns 0 (the "else" branch) once both sides are known and equal' do
      mapper.records_for('sensor/x', '10')
      hash = mapper.records_for('sensor/y', '10')

      expect(hash).to eq(
        [
          { field: 'y', measurement: 'PV', value: 10 },
          { field: 'different', measurement: 'PV', value: 0 },
        ],
      )
    end

    it 'returns the mapping value (the "then" branch) once both sides differ' do
      mapper.records_for('sensor/x', '10')
      mapper.records_for('sensor/y', '10')
      hash = mapper.records_for('sensor/x', '20')

      expect(hash).to eq(
        [
          { field: 'x', measurement: 'PV', value: 20 },
          { field: 'different', measurement: 'PV', value: 20 },
        ],
      )
    end
  end

  context 'with MAPPING_X_AGGREGATE_INTERVAL' do
    subject(:mapper) { described_class.new(config:) }

    let(:config) { Config.new(AGGREGATE_ENV, logger:) }
    let(:logger) { MemoryLogger.new }

    def at(time)
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(time)
    end

    it 'does not affect a mapping without AGGREGATE_INTERVAL' do
      at(1000.0)
      hash = mapper.records_for('sensor/plain', '42')

      expect(hash).to eq([{ field: 'plain_value', measurement: 'PV', value: 42 }])
    end

    it 'collects values without writing anything until the interval elapses' do
      at(1000.0)
      hash = mapper.records_for('sensor/fast', '10')
      expect(hash).to eq([])

      at(1002.0) # 2s later - still within the 5s window
      hash = mapper.records_for('sensor/fast', '20')
      expect(hash).to eq([])
    end

    it 'writes the average of all collected values once the interval elapses' do
      at(1000.0)
      mapper.records_for('sensor/fast', '10')

      at(1002.0)
      mapper.records_for('sensor/fast', '20')

      at(1006.0) # 6s after the window started - beyond the 5s interval
      hash = mapper.records_for('sensor/fast', '30')

      # average of 10, 20, 30 == 20
      expect(hash).to eq([{ field: 'fast_value', measurement: 'PV', value: 20 }])
    end

    it 'starts a fresh window after flushing, instead of carrying over old values' do
      at(1000.0)
      mapper.records_for('sensor/fast', '10')

      at(1006.0)
      mapper.records_for('sensor/fast', '20') # flushes average of [10, 20] == 15

      at(1007.0) # new window just started - not yet due
      hash = mapper.records_for('sensor/fast', '100')
      expect(hash).to eq([])

      at(1012.0) # 5s into the new window
      hash = mapper.records_for('sensor/fast', '200')
      expect(hash).to eq([{ field: 'fast_value', measurement: 'PV', value: 150 }])
    end

    it 'applies the aggregation before splitting into positive/negative fields' do
      at(1000.0)
      mapper.records_for('sensor/signed', '-10')

      at(1006.0)
      hash = mapper.records_for('sensor/signed', '30')

      # average of -10 and 30 == 10 (positive)
      expect(hash).to eq(
        [
          { field: 'signed_minus', measurement: 'PV', value: 0 },
          { field: 'signed_plus', measurement: 'PV', value: 10 },
        ],
      )
    end
  end
end
