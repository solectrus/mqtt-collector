class MemoryLogger
  def initialize
    @info_messages = []
    @error_messages = []
    @warn_messages = []
    @debug_messages = []
  end

  attr_reader :info_messages, :error_messages

  def info(message)
    @info_messages << message
  end

  def error(message)
    @error_messages << message
  end

  def warn(message)
    @warn_messages << message
  end

  def debug(message)
    @debug_messages << message
  end
end
