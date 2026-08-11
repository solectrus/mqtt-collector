require 'flux_writer'
require 'config'

describe FluxWriter do
  subject(:flux_writer) { described_class.new(config) }

  let(:config) { Config.new(ENV, logger: MemoryLogger.new) }

  describe '#ready?' do
    it 'returns true when InfluxDB responds to ping', vcr: 'influx_success' do
      expect(flux_writer.ready?).to be true
    end

    it 'returns false when InfluxDB is unreachable' do
      stub_request(:get, 'http://localhost:8086/ping').to_raise(Errno::ECONNREFUSED)

      expect(flux_writer.ready?).to be false
    end
  end

  describe '#push' do
    it 'writes the records to InfluxDB', vcr: 'influx_success' do
      records = [{ measurement: 'PV', field: 'battery_soc', value: 80.0 }]

      expect { flux_writer.push(records, time: 1_726_812_261) }.not_to raise_error
    end
  end
end
