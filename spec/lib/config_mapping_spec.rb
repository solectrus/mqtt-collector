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
      # Virtual mapping (no topic) is missing the formula
      {
        MAPPING_0_MEASUREMENT: 'measurement',
        MAPPING_0_FIELD: 'field',
        MAPPING_0_TYPE: 'float',
      },
      # Virtual mapping (no topic) cannot use JSON_KEY
      {
        MAPPING_0_MEASUREMENT: 'measurement',
        MAPPING_0_FIELD: 'field',
        MAPPING_0_TYPE: 'float',
        MAPPING_0_FORMULA: '{MAPPING_1}',
        MAPPING_0_JSON_KEY: 'key',
      },
    ].each do |hash|
      let(:env) { other_env.merge(hash) }

      it 'raises an error' do
        expect { config }.to raise_error(Config::Error)
      end
    end
  end

  context 'with valid virtual mapping env (no topic, calculated from other mappings)' do
    let(:env) do
      other_env.merge(
        {
          'MAPPING_0_TOPIC' => 'senec/0/ENERGY/GUI_INVERTER_POWER',
          'MAPPING_0_MEASUREMENT' => 'PV',
          'MAPPING_0_FIELD' => 'inverter_power',
          'MAPPING_0_TYPE' => 'integer',
          'MAPPING_0_NAME' => 'inverter_power',
          'MAPPING_1_MEASUREMENT' => 'PV',
          'MAPPING_1_FIELD' => 'inverter_power_doubled',
          'MAPPING_1_TYPE' => 'integer',
          'MAPPING_1_FORMULA' => '{inverter_power} * 2',
        },
      )
    end

    it 'returns mappings as array, including the virtual one without a topic' do
      expect(mappings).to eq(
        [
          {
            topic: 'senec/0/ENERGY/GUI_INVERTER_POWER',
            measurement: 'PV',
            field: 'inverter_power',
            type: 'integer',
            name: 'inverter_power',
            mapping_group: '0',
          },
          {
            measurement: 'PV',
            field: 'inverter_power_doubled',
            type: 'integer',
            formula: '{inverter_power} * 2',
            mapping_group: '1',
          },
        ],
      )
    end
  end

  context 'with blank variables (e.g. MAPPING_X_TOPIC= from a generated .env)' do
    let(:env) do
      other_env.merge(
        {
          'MAPPING_0_TOPIC' => 'senec/0/ENERGY/GUI_INVERTER_POWER',
          'MAPPING_0_MEASUREMENT' => 'PV',
          'MAPPING_0_FIELD' => 'inverter_power',
          'MAPPING_0_TYPE' => 'integer',
          'MAPPING_0_NAME' => 'inverter_power',
          'MAPPING_1_TOPIC' => '  ',
          'MAPPING_1_MEASUREMENT' => 'PV',
          'MAPPING_1_FIELD' => 'inverter_power_doubled',
          'MAPPING_1_TYPE' => 'integer',
          'MAPPING_1_FORMULA' => '{inverter_power} * 2',
        },
      )
    end

    it 'drops them, so a blank topic makes the mapping virtual' do
      expect(mappings[1]).not_to have_key(:topic)
    end
  end

  context 'when a referenced mapping is renumbered (e.g. by HELIOS re-generating the config)' do
    def env_with_inverter_at(index)
      other_env.merge(
        {
          "MAPPING_#{index}_TOPIC" => 'senec/0/ENERGY/GUI_INVERTER_POWER',
          "MAPPING_#{index}_MEASUREMENT" => 'PV',
          "MAPPING_#{index}_FIELD" => 'inverter_power',
          "MAPPING_#{index}_TYPE" => 'integer',
          "MAPPING_#{index}_NAME" => 'inverter_power',
          'MAPPING_9_MEASUREMENT' => 'PV',
          'MAPPING_9_FIELD' => 'inverter_power_doubled',
          'MAPPING_9_TYPE' => 'integer',
          'MAPPING_9_FORMULA' => '{inverter_power} * 2',
        },
      )
    end

    it 'still resolves the formula by name, regardless of the numeric index used' do
      original = described_class.new(env_with_inverter_at(0)).mappings
      renumbered = described_class.new(env_with_inverter_at(3)).mappings

      original_formula = original.find { |mapping| mapping[:formula] }
      renumbered_formula = renumbered.find { |mapping| mapping[:formula] }

      expect(original_formula[:formula]).to eq(renumbered_formula[:formula])
    end
  end
end
