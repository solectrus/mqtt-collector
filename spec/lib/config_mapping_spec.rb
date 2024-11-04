require 'config'

describe Config, '#mapping' do
  subject(:mappings) { config.mappings }

  let(:config) { described_class.new(env) }

  let(:other_env) do
    {
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
    }
  end

  context 'with valid mapping env' do
    let(:env) do
      other_env.merge(
        {
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
        },
      )
    end

    it 'returns mappings as array' do
      expect(mappings).to eq(
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
        ],
      )
    end
  end

  context 'with invalid mapping env' do
    [
      { MAPPING_0_TOPIC: 'topic' },
      { MAPPING_0_TOPIC: 'topic', MAPPING_0_FIELD: 'field' },
      { MAPPING_0_TOPIC: 'topic', MAPPING_0_MEASUREMENT: 'measurement' },
      {
        MAPPING_0_TOPIC: 'topic',
        MAPPING_0_MEASUREMENT: 'measurement',
        MAPPING_1_FIELD: 'field',
      },
    ].each do |hash|
      let(:env) { other_env.merge(hash) }

      it 'raises an error' do
        expect { config }.to raise_error(ConfigError)
      end
    end
  end
end
