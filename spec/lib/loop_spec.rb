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
  let(:fake_influx_push) do
    instance_double(InfluxPush, wait_until_ready: true, run: nil, shutdown: nil, enqueue: nil)
  end

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

        expect(logger.info_messages).to include(/Connected to MQTT broker/)
        expect(logger.info_messages).to include(/message = 80.0/)
        expect(logger.info_messages).to include(/PV:battery_soc = 80.0/)
        expect(logger.error_messages).to be_empty
      end
    end

    context 'when the MQTT server is not running' do
      before { allow(loop).to receive(:influx_push).and_return(fake_influx_push) }

      it 'handles errors' do
        loop.start

        expect(logger.error_messages).to include(
          /Connection refused.*will retry again in 1 seconds/,
        )
      end
    end

    context 'when interrupted' do
      before do
        allow(loop).to receive(:influx_push).and_return(fake_influx_push)
        allow(MQTT::Client).to receive(:new).and_raise(Interrupt)
      end

      it 'handles interruption' do
        loop.start

        expect(logger.warn_messages).to include(/Exiting/)
      end
    end

    context 'when terminated by a signal' do
      before do
        allow(loop).to receive(:influx_push).and_return(fake_influx_push)
        # "docker stop" sends SIGTERM, which raises SignalException and not
        # Interrupt
        allow(MQTT::Client).to receive(:new).and_raise(SignalException, 'TERM')
      end

      it 'shuts down like an interrupt' do
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

    context 'when the push thread dies unexpectedly' do
      before do
        allow(loop).to receive(:influx_push).and_return(fake_influx_push)
        allow(loop).to receive(:receive_loop) { sleep 2 }
        allow(loop).to receive(:push_loop).and_raise('the push thread is broken')
      end

      it 'ends instead of running on without a writer' do
        expect { loop.start }.to raise_error('the push thread is broken')
      end
    end

    context 'when the connection breaks while receiving' do
      let(:loop) { described_class.new(config:, retry_wait: 0) }
      let(:config) { Config.new(ENV.to_h, logger:) }

      it 'closes the broken connection and opens a new one' do
        client = instance_double(MQTT::Client, subscribe: nil)
        allow(MQTT::Client).to receive(:connect).and_return(client)
        allow(loop).to receive(:influx_push).and_return(fake_influx_push)
        # A connection that is already broken can refuse the disconnect too
        allow(client).to receive(:disconnect).and_raise(MQTT::ProtocolException, 'broken pipe')
        # Without max_count the loop retries forever, so the second attempt
        # ends it the way Ctrl-C does
        allow(client).to receive(:get).and_invoke(
          -> { raise 'connection lost' },
          -> { raise Interrupt },
        )

        loop.start

        expect(logger.error_messages).to include(/connection lost, will retry again in 0 seconds/)
        # Every attempt opens its own connection and closes it again
        expect(MQTT::Client).to have_received(:connect).twice
        expect(client).to have_received(:disconnect).twice
      end
    end

    context 'when a message maps to no records' do
      let(:loop) { described_class.new(config:, max_count: 2) }
      let(:config) { Config.new(ENV.to_h, logger:) }

      it 'queues the message that has records only' do
        topic = 'senec/0/ENERGY/GUI_BAT_DATA_FUEL_CHARGE'
        client = instance_double(MQTT::Client, subscribe: nil, disconnect: nil)
        allow(MQTT::Client).to receive(:connect).and_return(client)
        allow(loop).to receive(:influx_push).and_return(fake_influx_push)
        # An empty message maps to no record at all
        allow(client).to receive(:get).and_return([topic, ''], [topic, '80.0'])

        loop.start

        expect(fake_influx_push).to have_received(:enqueue).once
      end
    end

    context 'when shutting down' do
      before do
        allow(loop).to receive(:influx_push).and_return(fake_influx_push)
        allow(loop).to receive(:receive_loop)
        allow(loop).to receive(:push_loop)
      end

      it 'lets InfluxPush write what is left before ending' do
        loop.start

        expect(fake_influx_push).to have_received(:shutdown)
      end
    end
  end
end
