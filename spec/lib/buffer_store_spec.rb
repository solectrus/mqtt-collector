require 'tmpdir'
require 'buffer_store'

describe BufferStore do
  subject(:store) { described_class.new(logger:, path:) }

  let(:logger) { MemoryLogger.new }
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'data', 'buffer.jsonl') }

  let(:batches) do
    [
      { records: [{ measurement: 'PV', field: 'battery_soc', value: 80.0 }], time: 1_726_812_261 },
      {
        records: [
          { measurement: 'PV', field: 'inverter_power', value: 1500 },
          { measurement: 'PV', field: 'system_status', value: 'OK' },
          { measurement: 'PV', field: 'grid_export_limit_active', value: true },
        ],
        time: 1_726_812_262,
      },
    ]
  end

  after { FileUtils.remove_entry(dir) }

  describe '#save and #load' do
    it 'restores the batches with their values and types' do
      store.save(batches)

      expect(store.load).to eq(batches)
      expect(logger.info_messages).to include(/Saved 2 batch\(es\)/)
      expect(logger.info_messages).to include(/Restored 2 batch\(es\)/)
    end

    it 'deletes the file, so a batch is restored only once' do
      store.save(batches)
      store.load

      expect(File).not_to exist(path)
      expect(store.load).to eq([])
    end

    it 'leaves no temporary file behind' do
      store.save(batches)

      expect(Dir.children(File.dirname(path))).to eq(['buffer.jsonl'])
    end
  end

  describe '#save' do
    it 'writes no file when there is nothing to keep' do
      store.save([])

      expect(File).not_to exist(path)
      expect(logger.info_messages).to be_empty
    end

    it 'logs an error when the file cannot be written' do
      # A file where the directory should be
      File.write(File.join(dir, 'data'), '')

      store.save(batches)

      expect(logger.error_messages).to include(/Could not save 2 batch\(es\)/)
    end
  end

  describe '#load' do
    it 'returns nothing when no file was saved' do
      expect(store.load).to eq([])
      expect(logger.info_messages).to be_empty
      expect(logger.error_messages).to be_empty
    end

    it 'skips lines that are not a valid batch' do
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, <<~JSONL)
        {"records":[{"measurement":"PV","field":"battery_soc","value":80.0}],"time":1726812261}
        not json
        {"records":"broken","time":1726812262}
      JSONL

      expect(store.load).to eq([batches.first])
      expect(logger.error_messages).to include('Skipping invalid saved batch: not json')
      expect(logger.error_messages).to include(/Skipping invalid saved batch: \{"records":"broken"/)
    end

    it 'logs an error when the file cannot be read' do
      # A directory where the file should be
      FileUtils.mkdir_p(path)

      expect(store.load).to eq([])
      expect(logger.error_messages).to include(/Could not restore saved batches/)
    end
  end
end
