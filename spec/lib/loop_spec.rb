require 'loop'
require 'config'

describe Loop do
  subject(:loop) { described_class.new(config:, max_count: 1, retry_wait: 1) }

  let(:config) do
    Config.new(
      ENV.to_h.merge('MQTT_HOST' => server.address, 'MQTT_PORT' => server.port),
      logger:,
    )
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
      before { server.start(payload_to_publish: '80.0') }

      after { server.stop }

      it 'handles payload', vcr: 'influx_success' do
        loop.start

        expect(logger.info_messages).to include(/message = 80.0/)
        expect(logger.info_messages).to include(/PV:battery_soc = 80.0/)
        expect(logger.error_messages).to be_empty

        loop.stop
      end
    end

    context 'when the MQTT server is not running' do
      it 'handles errors' do
        loop.start

        expect(logger.error_messages).to include(
          /Connection refused.*will retry again in 1 seconds/,
        )

        loop.stop
      end
    end

    context 'when interrupted' do
      before { allow(MQTT::Client).to receive(:new).and_raise(Interrupt) }

      it 'handles interruption' do
        loop.start

        expect(logger.warn_messages).to include(/Exiting/)
      end
    end
  end
end
