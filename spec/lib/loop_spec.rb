require 'loop'
require 'config'

describe Loop do
  subject(:loop) { described_class.new(config:, max_count: 1, retry_wait: 1) }

  let(:config) do
    config = Config.from_env(mqtt_host: server.address, mqtt_port: server.port)
    config.logger = logger
    config
  end
  let(:logger) { MemoryLogger.new }

  let(:server) do
    server = MQTT::FakeServer.new
    server.just_one_connection = true
    server.logger = logger
    server
  end

  describe '#start' do
    context 'when the MQTT server is running' do
      before do
        server.start(payload_to_publish: '80.0')
      end

      after do
        server.stop
      end

      it 'handles payload', vcr: 'influx_success' do
        loop.start

        expect(logger.info_messages).to include(/{"bat_fuel_charge"=>80/)

        loop.stop
      end
    end

    context 'when the MQTT server is not running' do
      it 'handles errors' do
        loop.start

        expect(logger.error_messages).to include(/Connection refused.*will retry again in 1 seconds/)

        loop.stop
      end
    end
  end
end
