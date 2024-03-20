require 'config'
require 'climate_control'

describe Config do
  let(:config) { ClimateControl.modify(valid_env) { described_class.from_env } }

  let(:valid_env) do
    {
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
    }
  end

  describe 'valid options' do
    it 'initializes successfully' do
      expect(config).to be_a(described_class)
    end
  end

  describe 'mqtt credentials' do
    it 'matches the environment variables' do
      expect(config.mqtt_host).to eq(valid_env[:MQTT_HOST])
      expect(config.mqtt_port).to eq(valid_env[:MQTT_PORT])
      expect(config.mqtt_username).to eq(valid_env[:MQTT_USERNAME])
      expect(config.mqtt_password).to eq(valid_env[:MQTT_PASSWORD])
      expect(config.mqtt_url).to eq('mqtt://1.2.3.4:1883')
      expect(config.mqtt_ssl).to be false
    end
  end

  describe 'MQTT topics' do
    it 'matches the environment variables for MQTT topics' do
      expect(config.mqtt_topic_house_pow).to eq('senec/0/ENERGY/GUI_HOUSE_POW')
      expect(config.mqtt_topic_grid_pow).to eq('senec/0/ENERGY/GUI_GRID_POW')
      expect(config.mqtt_topic_bat_fuel_charge).to eq('senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE')
      expect(config.mqtt_topic_bat_power).to eq('senec/0/ENERGY/GUI_BAT_DATA_POWER')
      expect(config.mqtt_topic_case_temp).to eq('senec/0/TEMPMEASURE/CASE_TEMP')
      expect(config.mqtt_topic_current_state).to eq('senec/0/ENERGY/STAT_STATE_Text')
      expect(config.mqtt_topic_mpp1_power).to eq('senec/0/PV1/MPP_POWER/0')
      expect(config.mqtt_topic_mpp2_power).to eq('senec/0/PV1/MPP_POWER/1')
      expect(config.mqtt_topic_mpp3_power).to eq('senec/0/PV1/MPP_POWER/2')
      expect(config.mqtt_topic_inverter_power).to eq('senec/0/ENERGY/GUI_INVERTER_POWER')
      expect(config.mqtt_topic_wallbox_charge_power).to eq('senec/0/WALLBOX/APPARENT_CHARGING_POWER/0')
      expect(config.mqtt_topic_heatpump_power).to eq('somewhere/HEATPUMP/POWER')
    end
  end

  describe 'MQTT flip options' do
    context 'when MQTT_FLIP_BAT_POWER is true' do
      before { valid_env[:MQTT_FLIP_BAT_POWER] = 'true' }

      it 'enables bat power flip' do
        expect(config.mqtt_flip_bat_power).to be true
      end
    end

    context 'when MQTT_FLIP_BAT_POWER is false' do
      before { valid_env[:MQTT_FLIP_BAT_POWER] = 'false' }

      it 'disables bat power flip' do
        expect(config.mqtt_flip_bat_power).to be false
      end
    end

    context 'when MQTT_FLIP_GRID_POW is true' do
      before { valid_env[:MQTT_FLIP_GRID_POW] = 'true' }

      it 'enables grid power flip' do
        expect(config.mqtt_flip_grid_pow).to be true
      end
    end

    context 'when MQTT_FLIP_GRID_POW is false' do
      before { valid_env[:MQTT_FLIP_GRID_POW] = 'false' }

      it 'disables grid power flip' do
        expect(config.mqtt_flip_grid_pow).to be false
      end
    end
  end

  describe 'Influx methods' do
    it 'matches the environment variables for Influx' do
      expect(config.influx_host).to eq(valid_env[:INFLUX_HOST])
      expect(config.influx_schema).to eq(valid_env[:INFLUX_SCHEMA])
      expect(config.influx_port).to eq(valid_env[:INFLUX_PORT])
      expect(config.influx_token).to eq(valid_env[:INFLUX_TOKEN])
      expect(config.influx_org).to eq(valid_env[:INFLUX_ORG])
      expect(config.influx_bucket).to eq(valid_env[:INFLUX_BUCKET])
      expect(config.influx_url).to eq('https://influx.example.com:443')
    end
  end

  describe 'invalid options' do
    it 'raises an exception for empty configs' do
      expect { described_class.new({}) }.to raise_error(Exception)
      expect { described_class.new(influx_host: 'this is no host') }.to raise_error(Exception)
    end
  end
end
