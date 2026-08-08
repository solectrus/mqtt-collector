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

        fake_influx_push = instance_double(InfluxPush)
        allow(fake_influx_push).to receive(:ready?).and_return(false, true)
        allow(loop).to receive(:influx_push).and_return(fake_influx_push)
      end

      it 'waits and retries the readiness check before continuing' do
        loop.start

        expect(logger.info_messages).to include(/Wait until InfluxDB is ready/)
        expect(logger.info_messages).to include(/InfluxDB is ready/)
      end
    end

    context 'when the queue takes a moment to drain' do
      before do
        allow(loop).to receive(:sleep)
        allow(loop).to receive(:influx_ready?).and_return(true)
        allow(loop).to receive(:receive_loop)
        allow(loop).to receive(:push_loop)

        fake_queue = Queue.new
        fake_queue << { records: [], time: 0 }
        allow(fake_queue).to receive(:empty?).and_return(false, true)
        allow(Queue).to receive(:new).and_return(fake_queue)
      end

      it 'logs progress while waiting for the queue to drain' do
        loop.start

        expect(logger.info_messages).to include(/Waiting for 1 batch\(es\) to be pushed to InfluxDB/)
      end
    end
  end
end
