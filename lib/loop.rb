require 'mqtt'
require 'influxdb-client'
require 'influx_push'
require 'mapper'

class Loop
  extend Forwardable

  def_delegators :config, :logger

  def initialize(config:, retry_wait: 5, max_count: nil, max_wait: 12)
    @config = config
    @max_count = max_count
    @retry_wait = retry_wait
    @max_wait = max_wait
  end

  attr_reader :config, :max_count, :retry_wait, :max_wait

  def start
    return unless influx_ready?

    receive_thread =
      Thread.new do
        # start joins this thread and logs what it raises, so the default
        # report on stderr would only repeat it. The flag has to be set from
        # inside, because the thread can raise before a caller reaches it.
        Thread.current.report_on_exception = false

        receive_loop
      end

    push_thread =
      Thread.new do
        # Nobody joins this thread, so a fatal error in it would go unnoticed.
        # The collector would keep filling the queue and drop every batch at
        # the limit. Ending the process instead lets Docker restart it.
        Thread.current.abort_on_exception = true

        # The error reaches the main thread through the flag above, and Ruby
        # reports it from there. A report here as well would only double it.
        Thread.current.report_on_exception = false

        push_loop
      end

    # Wait for the receive thread to finish (will happen if max_count is set)
    receive_thread.join
  rescue SystemExit, SignalException
    # Ctrl-C raises Interrupt, "docker stop" raises SignalException. Interrupt
    # is one of those, so both arrive here and the ensure below does the work.
    logger.warn 'Exiting...'
  ensure
    # Stop receiving MQTT messages first. Otherwise the queue keeps growing
    # while it is drained, and the shutdown gives up on more than it had.
    stop_receiving(receive_thread)

    # Push any remaining records to InfluxDB (can take a while, but not forever)
    influx_push.shutdown

    # Stop pushing data to InfluxDB
    push_thread&.exit
  end

  def stop
    mqtt_client&.disconnect
  rescue MQTT::ProtocolException, StandardError => e
    handle_exception(e)
  end

  private

  # Receive MQTT messages and add the resulting records to the queue, for
  # InfluxPush to write - reconnects to the broker on error.
  def receive_loop
    subscribe_topics
    receive_messages
  rescue MQTT::ProtocolException, StandardError => e
    handle_exception(e)

    sleep(retry_wait)
    # TODO: Use exponential backoff instead of fixed timeout
    # Maybe use this gem: https://github.com/kamui/retriable

    retry if max_count.nil?
  end

  def subscribe_topics
    # Subscribe to all topics
    mapper.topics.each { |topic| mqtt_client.subscribe(topic) }
  end

  def receive_messages
    # (Mostly) endless loop to receive messages
    count = 0
    loop do
      time, records = next_message
      influx_push.enqueue(records:, time: time.to_i) if records.any?

      count += 1
      break if max_count && count >= max_count
    end
  end

  def next_message
    topic, message = mqtt_client.get

    # There is no timestamp in the MQTT message, so we use the current time.
    # This travels with the records through the queue, so a write that's
    # delayed by a retry still lands at the time the message actually arrived.
    time = Time.now

    # Log all the data we received
    logger.info "# Message from #{time}"
    logger.info "  topic = #{topic}"
    logger.info "  message = #{message}"

    # Convert the message to records
    records = mapper.records_for(topic, message)

    # Log all the data we are going to push to InfluxDB
    records.each do |record|
      logger.info "  => #{record[:measurement]}:#{record[:field]} = #{record[:value]}"
    end

    [time, records]
  end

  # Wait until InfluxDB is reachable, for up to max_wait seconds
  def influx_ready?
    logger.info 'Wait until InfluxDB is ready ...'

    started = monotonic_time
    sleep 1 until (ready = influx_push.ready?) || waited_long_enough?(started)

    if ready
      logger.info 'InfluxDB is ready.'
      true
    else
      waited = (monotonic_time - started).round
      logger.error "InfluxDB not ready after #{waited} seconds - aborting."
      false
    end
  end

  # A ping can block for as long as the HTTP timeout, so the loop counts real
  # seconds. Counting the attempts instead would report 12 seconds for a wait
  # that took minutes.
  def waited_long_enough?(started)
    max_wait && monotonic_time - started >= max_wait
  end

  # Not affected by a change of the system clock, unlike Time.now
  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Ends the receive thread and waits for it, so nothing reaches the queue
  # after this point. Thread#kill alone only asks the thread to stop, and a
  # message that arrives after that is counted but never written.
  #
  # Thread#join raises what the thread raised. start has already reported
  # that, so it is ignored here.
  def stop_receiving(thread)
    return unless thread

    thread.kill
    thread.join(1)
  rescue SignalException, StandardError
    nil
  end

  # Push records from the queue to InfluxDB
  def push_loop
    influx_push.run
  end

  def influx_push
    @influx_push ||= InfluxPush.new(config:)
  end

  def mqtt_client
    @mqtt_client ||= MQTT::Client.connect(mqtt_credentials)
  end

  def mqtt_credentials
    {
      host: config.mqtt_host,
      port: config.mqtt_port,
      ssl: config.mqtt_ssl,
      username: config.mqtt_username,
      password: config.mqtt_password,
      client_id: "mqtt-collector-#{SecureRandom.hex(4)}",
    }.compact
  end

  def mapper
    @mapper ||= Mapper.new(config:)
  end

  def handle_exception(error)
    logger.error "#{Time.now}: #{error}, will retry again in #{retry_wait} seconds..."

    # Reset MQTT client, so it will reconnect next time
    @mqtt_client&.disconnect
    @mqtt_client = nil
  end
end
