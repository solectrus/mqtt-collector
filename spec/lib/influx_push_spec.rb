require 'timeout'
require 'influx_push'
require 'config'

describe InfluxPush do
  subject(:influx_push) { described_class.new(config:, retry_delay: 0.1) }

  # Specs about the window set their own; everything else writes at once
  before { stub_const('InfluxPush::LINGER', 0) }

  let(:config) { Config.new(ENV, logger:) }
  let(:logger) { MemoryLogger.new }
  let(:records) { [{ measurement: 'PV', field: 'battery_soc', value: 80.0 }] }
  let(:time) { 1_726_812_261 }

  describe '#ready?' do
    it 'delegates to FluxWriter#ready?', vcr: 'influx_success' do
      expect(influx_push.ready?).to be true
    end
  end

  describe '#wait_until_ready' do
    it 'waits and asks again until InfluxDB answers' do
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:ready?).and_return(false, true)
        end,
      )
      push = described_class.new(config:)
      allow(push).to receive(:sleep)

      push.wait_until_ready(timeout: 12)

      expect(logger.info_messages).to include(/Wait until InfluxDB is ready/)
      expect(logger.info_messages).to include(/InfluxDB is ready/)
      expect(push).to have_received(:sleep).once
    end

    it 'reports the seconds it really waited, not the number of attempts' do
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter, ready?: false),
      )
      push = described_class.new(config:)
      # A single attempt that blocks for 30 seconds, as an HTTP timeout does
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(0, 30, 30)

      push.wait_until_ready(timeout: 12)

      expect(logger.error_messages).to include(/InfluxDB not ready after 30 seconds - starting anyway/)
    end

    it 'does not report the outage again on the first failed write' do
      attempts = 0
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter, ready?: false).tap do |writer|
          allow(writer).to receive(:push) do
            attempts += 1
            raise 'temporarily unreachable'
          end
        end,
      )
      push = described_class.new(config:, retry_delay: 0.01)
      push.wait_until_ready(timeout: 0)

      push.enqueue(records:, time:)
      thread = Thread.new { push.run }
      Timeout.timeout(2) { sleep 0.01 until attempts >= 2 }

      expect(logger.error_messages.grep(/Error while pushing/)).to be_empty
      expect(logger.error_messages).to include(/InfluxDB unreachable for \d+s/)

      push.queue.close
      thread.exit
    end
  end

  describe '#run' do
    it 'pushes a single queued batch to InfluxDB', vcr: 'influx_success' do
      influx_push.enqueue(records:, time:)

      run_until_drained

      expect(logger.info_messages).to include(/Successfully pushed 1 record\(s\) from .* to InfluxDB/)
      expect(logger.error_messages).to be_empty
    end

    it 'pushes the batches that are already waiting in one request', vcr: 'influx_success' do
      2.times { influx_push.enqueue(records:, time:) }

      run_until_drained

      expect(logger.info_messages).to include(
        /Successfully pushed 2 record\(s\) from 2 message\(s\) to InfluxDB/,
      )
      expect(WebMock).to have_requested(:post, %r{/api/v2/write}).once
    end

    it 'limits how many records go into one request', vcr: 'influx_success' do
      stub_const('InfluxPush::MAX_RECORDS_PER_WRITE', 2)

      3.times { influx_push.enqueue(records:, time:) }

      run_until_drained

      # Two records fill the first request, the third one goes out alone
      expect(logger.info_messages).to include(/pushed 2 record\(s\) from 2 message\(s\)/)
      expect(logger.info_messages).to include(/pushed 1 record\(s\) from 1 message\(s\)/)
    end

    it 'waits a moment for the messages that belong to the same reading' do
      pushed = Queue.new
      allow(FluxWriter).to receive(:new).and_return(collecting_flux_writer(pushed))
      stub_const('InfluxPush::LINGER', 0.5)
      influx_push = described_class.new(config:)

      thread = Thread.new { influx_push.run }
      influx_push.enqueue(records: [records.first.merge(field: 'first')], time:)
      # The second message arrives while the first one is still waiting
      sleep 0.05
      influx_push.enqueue(records: [records.first.merge(field: 'second')], time:)

      batches = Timeout.timeout(2) { pushed.pop }
      expect(batches.flat_map { |batch| batch[:records] }.map { |record| record[:field] }).to eq(%w[first second])
      expect(pushed).to be_empty

      influx_push.shutdown
      thread.join
    end

    it 'stops waiting for more messages once the shutdown starts' do
      # Every batch fills a request on its own, so the first one goes out
      # without waiting - and the second one meets a shutdown in progress
      stub_const('InfluxPush::MAX_RECORDS_PER_WRITE', 1)
      writing = Queue.new
      finish = Queue.new
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do
            writing << true
            finish.pop
          end
        end,
      )
      # Long enough that the shutdown could never wait it out
      stub_const('InfluxPush::LINGER', 30)
      influx_push = described_class.new(config:)

      2.times { influx_push.enqueue(records:, time:) }
      thread = Thread.new { influx_push.run }

      Timeout.timeout(2) { writing.pop }
      shutdown = Thread.new { influx_push.shutdown }
      sleep 0.05
      finish << true

      Timeout.timeout(2) { writing.pop }
      finish << true

      expect(shutdown.join(3)).to eq(shutdown)
      expect(thread.join(2)).to eq(thread)
      expect(influx_push.pending).to eq(0)
    end

    it 'keeps retrying a batch that keeps failing, instead of dropping it' do
      allow(FluxWriter).to receive(:new).and_return(always_failing_flux_writer)

      influx_push.enqueue(records:, time:)

      thread = Thread.new { influx_push.run }

      expect { Timeout.timeout(0.5) { sleep 0.01 until influx_push.pending.zero? } }.to raise_error(
        Timeout::Error,
      )

      expect(logger.error_messages).to include(/Error while pushing to InfluxDB: temporarily unreachable/)
      expect(logger.error_messages).to include(/Records are kept in the queue/)
      expect(influx_push.pending).to eq(1)

      influx_push.queue.close
      thread.exit
    end

    it 'delivers a batch with its original timestamp once InfluxDB recovers' do
      pushed = Queue.new
      attempts = 0

      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do |batches|
            attempts += 1
            raise 'temporarily unreachable' if attempts == 1

            pushed << batches.first
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

    it 'logs the details of the first failure, a status line for every retry, and the recovery' do
      attempts = 0
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do
            attempts += 1
            raise 'temporarily unreachable' if attempts <= 3
          end
        end,
      )

      influx_push.enqueue(records:, time:)
      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { sleep 0.01 until influx_push.pending.zero? }

      expect(attempts).to eq(4)
      expect(logger.error_messages.grep(/Error while pushing/).size).to eq(1)
      expect(logger.error_messages.grep(
        /InfluxDB unreachable for 0s \(temporarily unreachable\) - 1 batch\(es\) waiting, collecting continues/,
      ).size).to eq(2)
      expect(logger.info_messages).to include(/InfluxDB is available again after 0s, 0 batch\(es\) remaining/)

      influx_push.shutdown
      thread.join
    end
  end

  describe 'the duration of an outage' do
    {
      59 => '59s',
      60 => '1m 0s',
      3599 => '59m 59s',
      3600 => '1h 0m',
      90_061 => '25h 1m',
    }.each do |seconds, text|
      it "names #{seconds} seconds as #{text}" do
        influx_push.instance_variable_set(:@failing_since, 0)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(seconds)

        influx_push.send(:report_recovery)

        expect(logger.info_messages).to include(/available again after #{text},/)
      end
    end
  end

  describe 'an error InfluxDB will not accept' do
    it 'drops the batch instead of retrying it forever' do
      allow(FluxWriter).to receive(:new).and_return(failing_flux_writer(influx_error('422')))

      influx_push.enqueue(records:, time:)

      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { sleep 0.01 until influx_push.pending.zero? }

      expect(logger.error_messages).to include(/refused 1 record\(s\).*the batch is dropped/)
      expect(influx_push.queue).to be_empty

      influx_push.shutdown
      thread.join
    end

    it 'drops without waiting, so the queue keeps moving' do
      allow(FluxWriter).to receive(:new).and_return(failing_flux_writer(influx_error('422')))
      influx_push = described_class.new(config:, retry_delay: 5)

      3.times { |i| influx_push.enqueue(records:, time: i) }

      thread = Thread.new { influx_push.run }
      # A pause after each dropped batch would need 15 seconds for these three
      Timeout.timeout(1) { sleep 0.01 until influx_push.pending.zero? }

      influx_push.shutdown
      expect(thread.join(2)).to eq(thread)
    end

    it 'keeps the batches that share a request with a refused one' do
      broken_time = time + 1
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do |batches|
            raise influx_error('422') if batches.any? { |batch| batch[:time] == broken_time }
          end
        end,
      )

      influx_push.enqueue(records:, time:)
      influx_push.enqueue(records:, time: broken_time)
      influx_push.enqueue(records:, time:)

      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { sleep 0.01 until influx_push.pending.zero? }

      expect(logger.warn_messages).to include(/refused 3 record\(s\) from 3 message\(s\) - writing them one by one/)
      expect(logger.error_messages).to include(/refused 1 record\(s\).*the batch is dropped/)
      expect(logger.info_messages.grep(/Successfully pushed 1 record\(s\)/).size).to eq(2)

      influx_push.shutdown
      thread.join
    end

    it 'keeps retrying a server error, which a retry can fix' do
      allow(FluxWriter).to receive(:new).and_return(failing_flux_writer(influx_error('503')))

      influx_push.enqueue(records:, time:)

      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { sleep 0.01 until logger.error_messages.any?(/Records are kept in the queue/) }

      expect(influx_push.pending).to eq(1)

      influx_push.queue.close
      thread.exit
    end
  end

  describe 'the queue limit' do
    it 'drops the oldest batch instead of growing without a limit' do
      stub_const('InfluxPush::MAX_QUEUE_SIZE', 3)

      5.times { |i| influx_push.enqueue(records:, time: i) }

      expect(influx_push.queue.size).to eq(3)
      expect(influx_push.pending).to eq(3)
      expect(logger.warn_messages).to include(/queue holds 3 batches, which is the limit/)

      kept = Array.new(3) { influx_push.queue.pop[:time] }
      expect(kept).to eq([2, 3, 4])
    end

    it 'keeps the batch when the push thread emptied the queue first' do
      # A limit of 0 makes every enqueue look for a batch to drop, and finds
      # none - the same situation as a push thread that was quicker
      stub_const('InfluxPush::MAX_QUEUE_SIZE', 0)

      expect { influx_push.enqueue(records:, time: 1) }.not_to raise_error

      expect(influx_push.queue.size).to eq(1)
      expect(influx_push.pending).to eq(1)
    end
  end

  describe '#pending' do
    it 'counts a batch until InfluxDB has accepted it' do
      writing = Queue.new
      finish = Queue.new

      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do
            writing << true
            finish.pop
          end
        end,
      )

      expect(influx_push.pending).to eq(0)

      influx_push.enqueue(records:, time:)
      expect(influx_push.pending).to eq(1)

      thread = Thread.new { influx_push.run }

      # The batch has left the queue, but is not written yet
      Timeout.timeout(2) { writing.pop }
      expect(influx_push.queue).to be_empty
      expect(influx_push.pending).to eq(1)

      finish << true
      Timeout.timeout(2) { sleep 0.01 until influx_push.pending.zero? }

      influx_push.shutdown
      thread.join
    end
  end

  describe '#enqueue' do
    it 'keeps the count and the queue in step when the caller is killed' do
      # A shutdown kills the MQTT thread while it may sit inside enqueue
      20.times do
        push = described_class.new(config:)
        producer = Thread.new { loop { push.enqueue(records:, time:) } }
        sleep 0.002
        producer.kill
        producer.join

        expect(push.pending).to eq(push.queue.size)
      end
    end
  end

  describe '#shutdown' do
    it 'ends the run loop once everything is written', vcr: 'influx_success' do
      influx_push.enqueue(records:, time:)

      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { influx_push.shutdown }

      expect(thread.join(2)).to eq(thread)
      expect(influx_push.pending).to eq(0)
      expect(logger.error_messages).to be_empty
    end

    it 'waits for the pending batches and says how many are left' do
      allow(FluxWriter).to receive(:new).and_return(slow_flux_writer)

      influx_push.enqueue(records:, time:)

      thread = Thread.new { influx_push.run }
      Timeout.timeout(5) { influx_push.shutdown }
      thread.join

      expect(logger.info_messages).to include(/Waiting for 1 batch\(es\) to be pushed to InfluxDB/)
      expect(influx_push.pending).to eq(0)
    end

    it 'retries at once instead of sleeping through its own budget' do
      # The retry delay is as long as the shutdown budget. Without a wakeup the
      # batch never gets its second attempt, and a healthy InfluxDB loses it.
      attempts = 0
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do
            attempts += 1
            raise 'temporarily unreachable' if attempts == 1
          end
        end,
      )
      influx_push = described_class.new(config:, retry_delay: 5, shutdown_timeout: 5)

      influx_push.enqueue(records:, time:)
      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { sleep 0.01 until attempts == 1 }

      Timeout.timeout(3) { influx_push.shutdown }

      expect(thread.join(2)).to eq(thread)
      expect(attempts).to eq(2)
      expect(influx_push.pending).to eq(0)
      expect(logger.error_messages).not_to include(/giving up/)
    end

    it 'shortens the pause between retries, so a batch gets more than one attempt' do
      attempts = 0
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do
            attempts += 1
            raise 'temporarily unreachable'
          end
        end,
      )
      # The regular delay is longer than the whole shutdown budget
      influx_push = described_class.new(config:, retry_delay: 60, shutdown_timeout: 1)

      influx_push.enqueue(records:, time:)
      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { sleep 0.01 until attempts == 1 }

      Timeout.timeout(5) { influx_push.shutdown }
      thread.exit
      thread.join

      expect(attempts).to be > 2
      expect(influx_push.unwritten_batches.size).to eq(1)
    end

    it 'stops waiting when InfluxDB stays unreachable, and leaves the batches unwritten' do
      allow(FluxWriter).to receive(:new).and_return(always_failing_flux_writer)
      influx_push = described_class.new(config:, retry_delay: 0.01, shutdown_timeout: 0)

      20.times { |i| influx_push.enqueue(records:, time: i) }

      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { influx_push.shutdown }

      expect(logger.error_messages).to include(
        /InfluxDB is still unreachable after 0 seconds - 20 batch\(es\) not written/,
      )
      # The run loop keeps retrying until its thread is ended
      expect(thread).to be_alive

      thread.exit
      thread.join
      expect(influx_push.unwritten_batches.map { |batch| batch[:time] }).to match_array(0...20)
    end
  end

  describe '#unwritten_batches' do
    it 'is empty after everything is written', vcr: 'influx_success' do
      influx_push.enqueue(records:, time:)

      run_until_drained

      expect(influx_push.unwritten_batches).to be_empty
    end

    it 'returns the queued batches' do
      2.times { |i| influx_push.enqueue(records:, time: i) }

      expect(influx_push.unwritten_batches).to eq(
        [{ records:, time: 0 }, { records:, time: 1 }],
      )
      expect(influx_push.queue).to be_empty
    end

    it 'includes the batches of a request that is ended in the middle' do
      writing = Queue.new
      allow(FluxWriter).to receive(:new).and_return(
        instance_double(FluxWriter).tap do |writer|
          allow(writer).to receive(:push) do
            writing << true
            sleep
          end
        end,
      )

      2.times { |i| influx_push.enqueue(records:, time: i) }
      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { writing.pop }
      thread.exit
      thread.join

      expect(influx_push.queue).to be_empty
      expect(influx_push.unwritten_batches.map { |batch| batch[:time] }).to eq([0, 1])
    end

    it 'includes the batches collected while waiting for more messages' do
      stub_const('InfluxPush::LINGER', 30)
      influx_push.enqueue(records:, time:)
      thread = Thread.new { influx_push.run }
      # The run loop took the batch and waits for more
      Timeout.timeout(2) { sleep 0.01 until influx_push.queue.empty? && thread.status == 'sleep' }

      thread.exit
      thread.join

      expect(influx_push.unwritten_batches).to eq([{ records:, time: }])
    end

    it 'counts a batch that waits for its retry only once' do
      allow(FluxWriter).to receive(:new).and_return(always_failing_flux_writer)
      influx_push = described_class.new(config:, retry_delay: 30)

      influx_push.enqueue(records:, time:)
      thread = Thread.new { influx_push.run }
      Timeout.timeout(2) { sleep 0.01 until logger.error_messages.any?(/Records are kept in the queue/) }

      thread.exit
      thread.join

      expect(influx_push.unwritten_batches).to eq([{ records:, time: }])
    end
  end

  def run_until_drained
    thread = Thread.new { influx_push.run }
    Timeout.timeout(2) { influx_push.shutdown }
    thread.join
  end

  def influx_error(code)
    InfluxDB2::InfluxError.new(message: "refused with #{code}", code:, reference: '', retry_after: '')
  end

  def failing_flux_writer(error)
    instance_double(FluxWriter).tap do |writer|
      allow(writer).to receive(:push).and_raise(error)
    end
  end

  # Hands the batches of every request over, so a spec can see what went
  # together into one write
  def collecting_flux_writer(pushed)
    instance_double(FluxWriter).tap do |writer|
      allow(writer).to receive(:push) { |batches| pushed << batches }
    end
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
