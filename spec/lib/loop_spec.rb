require 'loop'
require 'config'

describe Loop do
  let(:loop) { described_class.new(config:, max_count: 1, retry_wait: 1) }

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
      before { allow(loop).to receive(:influx_ready?).and_return(true) }

      it 'handles errors' do
        loop.start

        expect(logger.error_messages).to include(
          /Connection refused.*will retry again in 1 seconds/,
        )

        loop.stop
      end
    end

    context 'when interrupted' do
      before do
        allow(loop).to receive(:influx_ready?).and_return(true)
        allow(MQTT::Client).to receive(:new).and_raise(Interrupt)
      end

      it 'handles interruption' do
        loop.start

        expect(logger.warn_messages).to include(/Exiting/)
      end
    end

    context 'when InfluxDB is not ready' do
      let(:loop) { described_class.new(config:, max_count: 1, max_wait: 0) }
      let(:config) { Config.new(ENV.to_h, logger:) }

      it 'aborts without ever subscribing to MQTT' do
        stub_request(:get, 'http://localhost:8086/ping').to_raise(Errno::ECONNREFUSED)
        allow(MQTT::Client).to receive(:connect)

        loop.start

        expect(MQTT::Client).not_to have_received(:connect)
        expect(logger.error_messages).to include(/InfluxDB not ready after 0 seconds - aborting/)
      end
    end

    context 'when InfluxDB becomes ready only after retrying' do
      before do
        allow(loop).to receive(:sleep)
        allow(loop).to receive(:receive_loop)
        allow(loop).to receive(:push_loop)

        allow(loop).to receive(:influx_push).and_return(fake_influx_push)
        allow(fake_influx_push).to receive(:ready?).and_return(false, true)
      end

      let(:fake_influx_push) { instance_double(InfluxPush, shutdown: nil) }

      it 'waits and retries the readiness check before continuing' do
        loop.start

        expect(logger.info_messages).to include(/Wait until InfluxDB is ready/)
        expect(logger.info_messages).to include(/InfluxDB is ready/)
      end
    end

    context 'when shutting down' do
      before do
        allow(loop).to receive_messages(influx_ready?: true, influx_push: fake_influx_push)
        allow(loop).to receive(:receive_loop)
        allow(loop).to receive(:push_loop)
      end

      let(:fake_influx_push) { instance_double(InfluxPush, shutdown: nil) }

      it 'lets InfluxPush write what is left before ending' do
        loop.start

        expect(fake_influx_push).to have_received(:shutdown)
      end
    end
  end
end
