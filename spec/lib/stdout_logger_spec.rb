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
end
