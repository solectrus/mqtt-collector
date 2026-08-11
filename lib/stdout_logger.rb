class StdoutLogger
  def initialize
    # Flush output immediately
    $stdout.sync = true

    # The thread that receives MQTT messages and the thread that pushes to
    # InfluxDB both log. Without this lock the two can write into the same
    # line, which makes the log unreadable at the moment it matters most.
    @mutex = Mutex.new
  end

  def info(message)
    write message
  end

  def error(message)
    # Red text by using ANSI escape code
    write "\e[31m#{message}\e[0m"
  end

  def debug(message)
    # Blue text by using ANSI escape code
    write "\e[34m#{message}\e[0m"
  end

  def warn(message)
    # Yellow text by using ANSI escape code
    write "\e[33m#{message}\e[0m"
  end

  private

  def write(message)
    @mutex.synchronize { $stdout.puts message }
  end
end
