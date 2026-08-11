require 'timeout'
require 'influx_push'
require 'config'

describe InfluxPush do
  subject(:influx_push) { described_class.new(config:, retry_delay: 0.1) }

  let(:config) { Config.new(ENV, logger:) }
  let(:logger) { MemoryLogger.new }
  let(:records) { [{ measurement: 'PV', field: 'battery_soc', value: 80.0 }] }
  let(:time) { 1_726_812_261 }

  describe '#ready?' do
    it 'delegates to FluxWriter#ready?', vcr: 'influx_success' do
      expect(influx_push.ready?).to be true
    end
  end

  describe '#run' do
    it 'pushes a single queued batch to InfluxDB', vcr: 'influx_success' do
      influx_push.enqueue(records:, time:)

      run_until_drained

      expect(logger.info_messages).to include(/Successfully pushed 1 record\(s\) from .* to InfluxDB/)
      expect(logger.error_messages).to be_empty
    end

    it 'pushes multiple queued batches to InfluxDB', vcr: 'influx_success' do
      2.times { influx_push.enqueue(records:, time:) }

      run_until_drained

      expect(logger.info_messages.grep(/Successfully pushed/).size).to eq(2)
    end

    it 'keeps retrying a batch that keeps failing, instead of dropping it' do
      allow(FluxWriter).to receive(:new).and_return(always_failing_flux_writer)

      influx_push.enqueue(records:, time:)

      thread = Thread.new { influx_push.run }

      expect { Timeout.timeout(0.5) { sleep 0.01 until influx_push.queue.empty? } }.to raise_error(
        Timeout::Error,
      )

      expect(logger.error_messages).to include(/Error while pushing to InfluxDB: temporarily unreachable/)
      expect(logger.info_messages).to include(/The batch has been queued again/)
      expect(influx_push.queue.size).to eq(1)

      influx_push.queue.close
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
      influx_push.enqueue(records:, time: original_time)

      thread = Thread.new { influx_push.run }

      delivered = Timeout.timeout(2) { pushed.pop }
      influx_push.shutdown
      thread.join

      expect(delivered[:time]).to eq(original_time)
      expect(logger.error_messages).to include(/Error while pushing to InfluxDB: temporarily unreachable/)
      expect(logger.info_messages).to include(/Successfully pushed 1 record\(s\)/)
    end
  end

  describe '#shutdown' do
    it 'ends the run loop once everything is written', vcr: 'influx_success' do
      influx_push.enqueue(records:, time:)

      thread = Thread.new { influx_push.run }
      Timeout.timeout(5) { influx_push.shutdown }

      expect(thread.join(2)).to eq(thread)
      expect(logger.error_messages).to be_empty
    end

    it 'logs progress while waiting for the queue to drain' do
      allow(FluxWriter).to receive(:new).and_return(slow_flux_writer)

      3.times { influx_push.enqueue(records:, time:) }

      thread = Thread.new { influx_push.run }
      Timeout.timeout(5) { influx_push.shutdown }
      thread.join

      expect(logger.info_messages).to include(/Waiting for \d batch\(es\) to be pushed to InfluxDB/)
    end
  end

  def run_until_drained
    thread = Thread.new { influx_push.run }
    Timeout.timeout(2) { influx_push.shutdown }
    thread.join
  end

  def always_failing_flux_writer
    instance_double(FluxWriter).tap do |writer|
      allow(writer).to receive(:push).and_raise('temporarily unreachable')
    end
  end

  # Takes long enough that the shutdown has to wait a round for it
  def slow_flux_writer
    instance_double(FluxWriter).tap do |writer|
      allow(writer).to receive(:push) { sleep 0.5 }
    end
  end
end
