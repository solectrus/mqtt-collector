require 'config'

describe Config do
  let(:config) { described_class.new(env) }

  let(:valid_env) do
    {
      'MQTT_HOST' => '1.2.3.4',
      'MQTT_PORT' => '1883',
      'MQTT_USERNAME' => 'username',
      'MQTT_PASSWORD' => 'password',
      'MQTT_SSL' => 'false',
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
      'MAPPING_3_TYPE' => 'integer',
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
      'MAPPING_6_FIELD' => 'wallbox_power',
      'MAPPING_6_TYPE' => 'integer',
      'MAPPING_7_TOPIC' => 'somewhere/HEATPUMP/POWER',
      'MAPPING_7_MEASUREMENT' => 'HEATPUMP',
      'MAPPING_7_FIELD' => 'power',
      'MAPPING_7_TYPE' => 'integer',
      'MAPPING_8_TOPIC' => 'senec/0/TEMPMEASURE/CASE_TEMP',
      'MAPPING_8_MEASUREMENT' => 'PV',
      'MAPPING_8_FIELD' => 'case_temp',
      'MAPPING_8_TYPE' => 'float',
      'MAPPING_9_TOPIC' => 'senec/0/ENERGY/STAT_STATE_Text',
      'MAPPING_9_MEASUREMENT' => 'PV',
      'MAPPING_9_FIELD' => 'system_status',
      'MAPPING_9_TYPE' => 'string',
      # ---
      'INFLUX_HOST' => 'influx.example.com',
      'INFLUX_SCHEMA' => 'https',
      'INFLUX_PORT' => '443',
      'INFLUX_TOKEN' => 'this.is.just.an.example',
      'INFLUX_ORG' => 'solectrus',
      'INFLUX_BUCKET' => 'my-bucket',
    }
  end

  let(:deprecated_env) do
    {
      'MQTT_HOST' => '1.2.3.4',
      'MQTT_PORT' => '1883',
      'MQTT_USERNAME' => 'username',
      'MQTT_PASSWORD' => 'password',
      'MQTT_SSL' => 'false',
      # ---
      'MQTT_TOPIC_HOUSE_POW' => 'senec/0/ENERGY/GUI_HOUSE_POW',
      'MQTT_TOPIC_GRID_POW' => 'senec/0/ENERGY/GUI_GRID_POW',
      'MQTT_TOPIC_BAT_FUEL_CHARGE' => 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE',
      'MQTT_TOPIC_BAT_POWER' => 'senec/0/ENERGY/GUI_BAT_DATA_POWER',
      'MQTT_TOPIC_CASE_TEMP' => 'senec/0/TEMPMEASURE/CASE_TEMP',
      'MQTT_TOPIC_CURRENT_STATE' => 'senec/0/ENERGY/STAT_STATE_Text',
      'MQTT_TOPIC_MPP1_POWER' => 'senec/0/PV1/MPP_POWER/0',
      'MQTT_TOPIC_MPP2_POWER' => 'senec/0/PV1/MPP_POWER/1',
      'MQTT_TOPIC_MPP3_POWER' => 'senec/0/PV1/MPP_POWER/2',
      'MQTT_TOPIC_INVERTER_POWER' => 'senec/0/ENERGY/GUI_INVERTER_POWER',
      'MQTT_TOPIC_WALLBOX_CHARGE_POWER' =>
        'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
      'MQTT_TOPIC_WALLBOX_CHARGE_POWER1' =>
        'senec/0/WALLBOX/APPARENT_CHARGING_POWER/1',
      'MQTT_TOPIC_WALLBOX_CHARGE_POWER2' =>
        'senec/0/WALLBOX/APPARENT_CHARGING_POWER/2',
      'MQTT_TOPIC_WALLBOX_CHARGE_POWER3' =>
        'senec/0/WALLBOX/APPARENT_CHARGING_POWER/3',
      'MQTT_TOPIC_POWER_RATIO' => 'senec/0/PV1/POWER_RATIO',
      'MQTT_TOPIC_HEATPUMP_POWER' => 'somewhere/HEATPUMP/POWER',
      # ---
      'MQTT_FLIP_BAT_POWER' => 'true',
      'MQTT_FLIP_GRID_POW' => 'true',
      # ---
      'INFLUX_HOST' => 'influx.example.com',
      'INFLUX_SCHEMA' => 'https',
      'INFLUX_PORT' => '443',
      'INFLUX_TOKEN' => 'this.is.just.an.example',
      'INFLUX_ORG' => 'solectrus',
      'INFLUX_BUCKET' => 'my-bucket',
      'INFLUX_MEASUREMENT' => 'PV',
    }
  end

  describe 'valid options' do
    let(:env) { valid_env }

    it 'initializes successfully' do
      expect(config).to be_a(described_class)
    end
  end

  describe 'mqtt credentials' do
    let(:env) { valid_env }

    it 'matches the environment variables' do
      expect(config.mqtt_host).to eq(valid_env['MQTT_HOST'])
      expect(config.mqtt_port).to eq(valid_env['MQTT_PORT'])
      expect(config.mqtt_username).to eq(valid_env['MQTT_USERNAME'])
      expect(config.mqtt_password).to eq(valid_env['MQTT_PASSWORD'])
      expect(config.mqtt_url).to eq('mqtt://1.2.3.4:1883')
      expect(config.mqtt_ssl).to be false
    end
  end

  describe '#mappings' do
    context 'when using valid environment variables' do
      let(:env) { valid_env }

      it 'matches the environment variables for MQTT topics' do
        expect(config.mappings).to eq(
          [
            {
              topic: 'senec/0/ENERGY/GUI_INVERTER_POWER',
              measurement: 'PV',
              field: 'inverter_power',
              type: 'integer',
              mapping_group: '0',
            },
            {
              topic: 'senec/0/ENERGY/GUI_HOUSE_POW',
              measurement: 'PV',
              field: 'house_power',
              type: 'integer',
              mapping_group: '1',
            },
            {
              topic: 'senec/0/ENERGY/GUI_GRID_POW',
              measurement_positive: 'PV',
              measurement_negative: 'PV',
              field_positive: 'grid_import_power',
              field_negative: 'grid_export_power',
              type: 'integer',
              mapping_group: '2',
            },
            {
              topic: 'senec/0/PV1/POWER_RATIO',
              measurement: 'PV',
              field: 'grid_export_limit',
              type: 'integer',
              mapping_group: '3',
            },
            {
              topic: 'senec/0/ENERGY/GUI_BAT_DATA_POWER',
              measurement_positive: 'PV',
              measurement_negative: 'PV',
              field_positive: 'battery_charging_power',
              field_negative: 'battery_discharging_power',
              type: 'integer',
              mapping_group: '4',
            },
            {
              topic: 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE',
              measurement: 'PV',
              field: 'battery_soc',
              type: 'float',
              mapping_group: '5',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
              measurement: 'PV',
              field: 'wallbox_power',
              type: 'integer',
              mapping_group: '6',
            },
            {
              topic: 'somewhere/HEATPUMP/POWER',
              measurement: 'HEATPUMP',
              field: 'power',
              type: 'integer',
              mapping_group: '7',
            },
            {
              topic: 'senec/0/TEMPMEASURE/CASE_TEMP',
              measurement: 'PV',
              field: 'case_temp',
              type: 'float',
              mapping_group: '8',
            },
            {
              topic: 'senec/0/ENERGY/STAT_STATE_Text',
              measurement: 'PV',
              field: 'system_status',
              type: 'string',
              mapping_group: '9',
            },
          ],
        )
      end
    end

    context 'when using deprecated environment variables (flipped)' do
      let(:env) do
        deprecated_env.merge(
          'MQTT_FLIP_BAT_POWER' => 'true',
          'MQTT_FLIP_GRID_POW' => 'true',
        )
      end

      it 'builds mappings' do
        expect(config.mappings).to eq(
          [
            {
              topic: 'senec/0/ENERGY/GUI_HOUSE_POW',
              measurement: 'PV',
              field: 'house_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/ENERGY/GUI_GRID_POW',
              measurement_positive: 'PV',
              measurement_negative: 'PV',
              field_positive: 'grid_power_minus',
              field_negative: 'grid_power_plus',
              type: 'integer',
            },
            {
              topic: 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE',
              measurement: 'PV',
              field: 'bat_fuel_charge',
              type: 'float',
            },
            {
              topic: 'senec/0/ENERGY/GUI_BAT_DATA_POWER',
              measurement_negative: 'PV',
              measurement_positive: 'PV',
              field_positive: 'bat_power_minus',
              field_negative: 'bat_power_plus',
              type: 'integer',
            },
            {
              topic: 'senec/0/TEMPMEASURE/CASE_TEMP',
              measurement: 'PV',
              field: 'case_temp',
              type: 'float',
            },
            {
              topic: 'senec/0/ENERGY/STAT_STATE_Text',
              measurement: 'PV',
              field: 'current_state',
              type: 'string',
            },
            {
              topic: 'senec/0/PV1/MPP_POWER/0',
              measurement: 'PV',
              field: 'mpp1_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/PV1/MPP_POWER/1',
              measurement: 'PV',
              field: 'mpp2_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/PV1/MPP_POWER/2',
              measurement: 'PV',
              field: 'mpp3_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/ENERGY/GUI_INVERTER_POWER',
              measurement: 'PV',
              field: 'inverter_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/PV1/POWER_RATIO',
              measurement: 'PV',
              field: 'power_ratio',
              type: 'integer',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
              measurement: 'PV',
              field: 'wallbox_charge_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/1',
              measurement: 'PV',
              field: 'wallbox_charge_power1',
              type: 'integer',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/2',
              measurement: 'PV',
              field: 'wallbox_charge_power2',
              type: 'integer',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/3',
              measurement: 'PV',
              field: 'wallbox_charge_power3',
              type: 'integer',
            },
            {
              topic: 'somewhere/HEATPUMP/POWER',
              measurement: 'PV',
              field: 'heatpump_power',
              type: 'integer',
            },
          ],
        )
      end
    end

    context 'when using deprecated environment variables (not flipped)' do
      let(:env) do
        deprecated_env.merge(
          'MQTT_FLIP_BAT_POWER' => 'false',
          'MQTT_FLIP_GRID_POW' => 'false',
        )
      end

      it 'builds mappings' do
        expect(config.mappings).to eq(
          [
            {
              topic: 'senec/0/ENERGY/GUI_HOUSE_POW',
              measurement: 'PV',
              field: 'house_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/ENERGY/GUI_GRID_POW',
              measurement_positive: 'PV',
              measurement_negative: 'PV',
              field_positive: 'grid_power_plus',
              field_negative: 'grid_power_minus',
              type: 'integer',
            },
            {
              topic: 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE',
              measurement: 'PV',
              field: 'bat_fuel_charge',
              type: 'float',
            },
            {
              topic: 'senec/0/ENERGY/GUI_BAT_DATA_POWER',
              measurement_negative: 'PV',
              measurement_positive: 'PV',
              field_positive: 'bat_power_plus',
              field_negative: 'bat_power_minus',
              type: 'integer',
            },
            {
              topic: 'senec/0/TEMPMEASURE/CASE_TEMP',
              measurement: 'PV',
              field: 'case_temp',
              type: 'float',
            },
            {
              topic: 'senec/0/ENERGY/STAT_STATE_Text',
              measurement: 'PV',
              field: 'current_state',
              type: 'string',
            },
            {
              topic: 'senec/0/PV1/MPP_POWER/0',
              measurement: 'PV',
              field: 'mpp1_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/PV1/MPP_POWER/1',
              measurement: 'PV',
              field: 'mpp2_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/PV1/MPP_POWER/2',
              measurement: 'PV',
              field: 'mpp3_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/ENERGY/GUI_INVERTER_POWER',
              measurement: 'PV',
              field: 'inverter_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/PV1/POWER_RATIO',
              measurement: 'PV',
              field: 'power_ratio',
              type: 'integer',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/0',
              measurement: 'PV',
              field: 'wallbox_charge_power',
              type: 'integer',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/1',
              measurement: 'PV',
              field: 'wallbox_charge_power1',
              type: 'integer',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/2',
              measurement: 'PV',
              field: 'wallbox_charge_power2',
              type: 'integer',
            },
            {
              topic: 'senec/0/WALLBOX/APPARENT_CHARGING_POWER/3',
              measurement: 'PV',
              field: 'wallbox_charge_power3',
              type: 'integer',
            },
            {
              topic: 'somewhere/HEATPUMP/POWER',
              measurement: 'PV',
              field: 'heatpump_power',
              type: 'integer',
            },
          ],
        )
      end
    end
  end

  describe 'Influx methods' do
    let(:env) { valid_env }

    it 'matches the environment variables for Influx' do
      expect(config.influx_host).to eq(valid_env['INFLUX_HOST'])
      expect(config.influx_schema).to eq(valid_env['INFLUX_SCHEMA'])
      expect(config.influx_port).to eq(valid_env['INFLUX_PORT'])
      expect(config.influx_token).to eq(valid_env['INFLUX_TOKEN'])
      expect(config.influx_org).to eq(valid_env['INFLUX_ORG'])
      expect(config.influx_bucket).to eq(valid_env['INFLUX_BUCKET'])
      expect(config.influx_url).to eq('https://influx.example.com:443')
    end
  end

  describe 'invalid options' do
    [
      ->(env) { env.except('MQTT_HOST') },
      ->(env) { env.except('MQTT_PORT') },
      ->(env) { env.except('INFLUX_HOST') },
      ->(env) { env.except('INFLUX_TOKEN') },
      ->(env) { env.except('INFLUX_ORG') },
      ->(env) { env.except('INFLUX_BUCKET') },
    ].each do |test_case|
      it 'raises an KeyError' do
        env = test_case.call(valid_env)

        expect { described_class.new(env) }.to raise_error(KeyError)
      end
    end
  end

  describe 'invalid mappings' do
    [
      # Missing keys (for a simple mapping)
      [:except, 'MAPPING_0_TOPIC', 'Missing variable: MAPPING_0_TOPIC'],
      [:except, 'MAPPING_0_FIELD', 'Missing variable: MAPPING_0_FIELD'],
      [:except, 'MAPPING_0_MEASUREMENT', 'Missing variable: MAPPING_0_MEASUREMENT'],
      [:except, 'MAPPING_0_TYPE', 'Missing variable: MAPPING_0_TYPE'],
      # Missing keys (for a positive/negative mapping)
      [:except, 'MAPPING_4_FIELD_POSITIVE', 'Missing variable: MAPPING_4_FIELD_POSITIVE'],
      [:except, 'MAPPING_4_FIELD_NEGATIVE', 'Missing variable: MAPPING_4_FIELD_NEGATIVE'],
      [:except, 'MAPPING_4_MEASUREMENT_POSITIVE', 'Missing variable: MAPPING_4_MEASUREMENT_POSITIVE'],
      [:except, 'MAPPING_4_MEASUREMENT_NEGATIVE', 'Missing variable: MAPPING_4_MEASUREMENT_NEGATIVE'],
      # Blank keys (for a simple mapping)
      [:merge, { 'MAPPING_0_TOPIC' => '' }, 'Missing variable: MAPPING_0_TOPIC'],
      [:merge, { 'MAPPING_0_FIELD' => '' }, 'Missing variable: MAPPING_0_FIELD'],
      [:merge, { 'MAPPING_0_MEASUREMENT' => '' }, 'Missing variable: MAPPING_0_MEASUREMENT'],
      [:merge, { 'MAPPING_0_TYPE' => '' }, 'Missing variable: MAPPING_0_TYPE'],
      # Blank keys (for a positive/negative mapping)
      [:merge, { 'MAPPING_4_FIELD_POSITIVE' => '' }, 'Missing variable: MAPPING_4_FIELD_POSITIVE'],
      [:merge, { 'MAPPING_4_MEASUREMENT_POSITIVE' => '' }, 'Missing variable: MAPPING_4_MEASUREMENT_POSITIVE'],
      [:merge, { 'MAPPING_4_FIELD_NEGATIVE' => '' }, 'Missing variable: MAPPING_4_FIELD_NEGATIVE'],
      [:merge, { 'MAPPING_4_MEASUREMENT_NEGATIVE' => '' }, 'Missing variable: MAPPING_4_MEASUREMENT_NEGATIVE'],
      # Superfluous keys
      [:merge, { 'MAPPING_4_FIELD' => 'foo' }, 'Unexpected variable: MAPPING_4_FIELD'],
      [:merge, { 'MAPPING_4_MEASUREMENT' => 'foo' }, 'Unexpected variable: MAPPING_4_MEASUREMENT'],
      [:merge, { 'MAPPING_0_MEASUREMENT_POSITIVE' => 'foo' }, 'Unexpected variable: MAPPING_0_MEASUREMENT_POSITIVE'],
      [:merge, { 'MAPPING_0_MEASUREMENT_NEGATIVE' => 'foo' }, 'Unexpected variable: MAPPING_0_MEASUREMENT_NEGATIVE'],
      # Invalid type
      [:merge, { 'MAPPING_0_TYPE' => 'this-is-no-type' }, 'Variable MAPPING_0_TYPE is invalid: this-is-no-type. ' \
                                                          'Must be one of: integer, float, string, boolean',],
    ].each do |test_case|
      message = test_case[2]

      it "raises an ConfigError ('#{message}')" do
        env = valid_env.public_send(test_case[0], test_case[1])

        expect { described_class.new(env) }.to raise_error(
          ConfigError,
        ).with_message(message)
      end
    end
  end
end
