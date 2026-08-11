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
    @influx_push = InfluxPush.new(config:)
    @mapper = Mapper.new(config:)
  end

  attr_reader :config, :max_count, :retry_wait, :max_wait

  def start
    return unless influx_push.wait_until_ready(timeout: max_wait)

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

  private

  attr_reader :influx_push, :mapper

  # Receive MQTT messages and add the resulting records to the queue, for
  # InfluxPush to write - reconnects to the broker on error.
  def receive_loop
    with_mqtt_client do |client|
      subscribe_topics(client)
      receive_messages(client)
    end
  rescue MQTT::ProtocolException, StandardError => e
    logger.error "#{Time.now}: #{e}, will retry again in #{retry_wait} seconds..."

    sleep(retry_wait)
    # TODO: Use exponential backoff instead of fixed timeout
    # Maybe use this gem: https://github.com/kamui/retriable

    retry if max_count.nil?
  end

  # Opens a connection for one attempt and closes it again, whatever ends the
  # attempt: an error, max_count, or the kill of the receive thread. The client
  # belongs to this loop alone, so a retry opens a new one and nothing outside
  # can keep a connection that is already broken.
  def with_mqtt_client
    client = MQTT::Client.connect(mqtt_credentials)
    yield client
  ensure
    disconnect(client)
  end

  # A connection that is already broken can refuse the disconnect as well,
  # which must not replace the error that ended the attempt.
  def disconnect(client)
    client&.disconnect
  rescue MQTT::ProtocolException, StandardError
    nil
  end

  def subscribe_topics(client)
    # Subscribe to all topics
    mapper.topics.each { |topic| client.subscribe(topic) }
  end

  def receive_messages(client)
    # (Mostly) endless loop to receive messages
    count = 0
    loop do
      topic, time, records = next_message(client)
      influx_push.enqueue(records:, time: time.to_i, topic:) if records.any?

      count += 1
      break if max_count && count >= max_count
    end
  end

  def next_message(client)
    topic, message = client.get

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

    [topic, time, records]
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
end
