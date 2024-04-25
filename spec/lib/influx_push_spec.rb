require 'influx_push'
require 'config'

describe InfluxPush do
  subject(:influx_push) { described_class.new(config:) }

  let(:config) { Config.new(ENV, logger: MemoryLogger.new) }

  it 'initializes with a config' do
    expect(influx_push.config).to eq(config)
  end

  it 'can push records to InfluxDB', vcr: 'influx_success' do
    time = Time.now
    records = [{ fields: { key: 'value' } }]

    influx_push.call(records, time:)
  end

  it 'can handle error' do
    fake_flux = instance_double(FluxWriter)
    allow(fake_flux).to receive(:push).and_raise(StandardError)
    allow(FluxWriter).to receive(:new).and_return(fake_flux)

    time = Time.now
    records = [{ fields: { key: 'value' } }]

    expect do
      influx_push.call(records, time:, retries: 1, retry_delay: 0.1)
    end.to raise_error(StandardError)

    expect(config.logger.error_messages).to include(
      'Error while pushing to InfluxDB: StandardError',
    )
    sleep(1)
  end
end
