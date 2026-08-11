require 'stdout_logger'

describe StdoutLogger do
  let(:logger) { described_class.new }

  let(:message) { 'This is the message' }

  describe '#info' do
    subject(:info) { logger.info(message) }

    it { expect { info }.to output(/#{message}/).to_stdout }
  end

  describe '#error' do
    subject(:error) { logger.error(message) }

    it { expect { error }.to output(/#{message}/).to_stdout }
    it { expect { error }.to output(/\e\[31m/).to_stdout }
  end

  describe '#debug' do
    subject(:debug) { logger.debug(message) }

    it { expect { debug }.to output(/#{message}/).to_stdout }
    it { expect { debug }.to output(/\e\[34m/).to_stdout }
  end

  describe '#warn' do
    subject(:warn) { logger.warn(message) }

    it { expect { warn }.to output(/#{message}/).to_stdout }
    it { expect { warn }.to output(/\e\[33m/).to_stdout }
  end

  describe 'logging from more than one thread' do
    # The collector receives and pushes in two threads, so both log at the
    # same time. This writes one character at a time and gives every other
    # thread a turn in between, which mixes the lines of a logger without a
    # lock.
    let(:written) { +'' }

    before do
      allow($stdout).to receive(:puts) do |line|
        "#{line}\n".each_char do |char|
          written << char
          Thread.pass
        end
      end
    end

    it 'writes every line as a whole' do
      threads = Array.new(4) { |i| Thread.new { 20.times { logger.info("line-of-thread-#{i}") } } }
      threads.each(&:join)

      expect(written.lines.size).to eq(80)
      expect(written.lines).to all(match(/\Aline-of-thread-\d\n\z/))
    end
  end
end
