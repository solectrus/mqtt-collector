require 'timeout'
require 'influx_push'
require 'config'

describe InfluxPush do
  subject(:influx_push) { described_class.new(config:, queue:, retry_delay: 0.1) }

  let(:config) { Config.new(ENV, logger:) }
  let(:logger) { MemoryLogger.new }
  let(:queue) { Queue.new }

  describe '#ready?' do
    it 'delegates to FluxWriter#ready?', vcr: 'influx_success' do
      expect(influx_push.ready?).to be true
    end
  end

  describe '#run' do
    it 'pushes a single queued batch to InfluxDB', vcr: 'influx_success' do
      queue << { records: [{ measurement: 'PV', field: 'battery_soc', value: 80.0 }], time: 1_726_812_261 }

      run_until_drained

      expect(logger.info_messages).to include(/Successfully pushed 1 record\(s\) from .* to InfluxDB/)
      expect(logger.error_messages).to be_empty
    end

    it 'pushes multiple queued batches to InfluxDB', vcr: 'influx_success' do
      2.times do
        queue << { records: [{ measurement: 'PV', field: 'battery_soc', value: 80.0 }], time: 1_726_812_261 }
      end

      run_until_drained

      expect(logger.info_messages.grep(/Successfully pushed/).size).to eq(2)
    end

    it 'keeps retrying a batch that keeps failing, instead of dropping it' do
      allow(FluxWriter).to receive(:new).and_return(always_failing_flux_writer)

      batch = { records: [{ measurement: 'PV', field: 'battery_soc', value: 80.0 }], time: 1_726_812_261 }
      queue << batch

      thread = Thread.new { influx_push.run }

      expect { Timeout.timeout(0.5) { loop until queue.empty? } }.to raise_error(Timeout::Error)

      expect(logger.error_messages).to include(/Error while pushing to InfluxDB: temporarily unreachable/)
      expect(logger.info_messages).to include(/The batch has been queued again/)
      expect(queue.size).to eq(1)

      queue.close
      thread.exit
    end

    it 'delivers a batch with its original timestamp once InfluxDB recovers' do
      pushed = Queue.new
      attempts = 0

      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do |records, time:|
            attempts += 1
            raise 'temporarily unreachable' if attempts == 1

            pushed << { records:, time: }
          end
        end,
      )

      original_time = 1_700_000_000
      queue << { records: [{ measurement: 'PV', field: 'battery_soc', value: 80.0 }], time: original_time }

      thread = Thread.new { influx_push.run }

      delivered = Timeout.timeout(2) { pushed.pop }
      queue.close
      thread.join

      expect(delivered[:time]).to eq(original_time)
      expect(logger.error_messages).to include(/Error while pushing to InfluxDB: temporarily unreachable/)
      expect(logger.info_messages).to include(/Successfully pushed 1 record\(s\)/)
    end
  end

  def run_until_drained
    thread = Thread.new { influx_push.run }
    Timeout.timeout(2) { sleep 0.01 until queue.empty? }
    queue.close
    thread.join
  end

  def always_failing_flux_writer
    instance_double(FluxWriter).tap do |writer|
      allow(writer).to receive(:push).and_raise('temporarily unreachable')
    end
  end
end
