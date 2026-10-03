require 'json'
require 'fileutils'

# Keeps the batches that did not reach InfluxDB before a shutdown in a file,
# so the next start can write them. Without a volume, the file lives in the
# container layer: it survives a restart of the container, but not its
# recreation, for example on an update.
class BufferStore
  DEFAULT_PATH = File.expand_path('../data/buffer.jsonl', __dir__)

  def initialize(logger:, path: DEFAULT_PATH)
    @logger = logger
    @path = path
  end

  attr_reader :logger, :path

  def save(batches)
    return if batches.empty?

    write(batches)
    logger.info "Saved #{batches.size} batch(es) to #{path}, to push them after the next start"
  rescue SystemCallError => e
    logger.error "Could not save #{batches.size} batch(es): #{e.message}"
  end

  # Returns the saved batches and deletes the file, so a batch is restored
  # only once
  def load
    batches = File.foreach(path).filter_map { |line| parse(line) }
    File.delete(path)

    logger.info "Restored #{batches.size} batch(es) from #{path}"
    batches
  rescue Errno::ENOENT
    []
  rescue SystemCallError => e
    logger.error "Could not restore saved batches: #{e.message}"
    []
  end

  private

  # Writes to a temporary file first, so an aborted write leaves no broken file
  def write(batches)
    FileUtils.mkdir_p(File.dirname(path))

    tmp_path = "#{path}.tmp"
    File.open(tmp_path, 'w') do |file|
      batches.each { |batch| file.puts(JSON.generate(batch, allow_nan: true)) }
    end
    File.rename(tmp_path, path)
  end

  def parse(line)
    case JSON.parse(line, symbolize_names: true, allow_nan: true)
    in { records: Array => records, time: Integer => time }
      { records:, time: }
    else
      skip(line)
    end
  rescue JSON::ParserError
    skip(line)
  end

  def skip(line)
    logger.error "Skipping invalid saved batch: #{line.strip}"
    nil
  end
end
