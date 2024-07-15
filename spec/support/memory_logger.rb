class MemoryLogger
  def initialize
    @info_messages = []
    @error_messages = []
    @warn_messages = []
    @debug_messages = []

    @mutex = Mutex.new
  end

  attr_reader :info_messages, :error_messages, :warn_messages, :debug_messages

  def info(message)
    synchronize { @info_messages << message }
  end

  def error(message)
    synchronize { @error_messages << message }
  end

  def warn(message)
    synchronize { @warn_messages << message }
  end

  def debug(message)
    synchronize { @debug_messages << message }
  end

  private

  def synchronize(&)
    @mutex.synchronize(&)
  end
end
