class StdoutLogger
  def initialize
    # Flush output immediately
    $stdout.sync = true
  end

  def info(message)
    puts message
  end

  def error(message)
    # Red text by using ANSI escape code
    puts "\e[31m#{message}\e[0m"
  end

  def debug(message)
    # Blue text by using ANSI escape code
    puts "\e[34m#{message}\e[0m"
  end

  def warn(message)
    # Yellow text by using ANSI escape code
    puts "\e[33m#{message}\e[0m"
  end
end
