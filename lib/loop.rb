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

    receive_thread = Thread.new { receive_loop }
    push_thread = Thread.new { push_loop }

    # Wait for the receive thread to finish (will happen if max_count is set)
    receive_thread.join
  rescue SystemExit, Interrupt
    logger.warn 'Exiting...'

    # Stop receiving MQTT messages
    receive_thread&.exit
  ensure
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

    count = 0
    until (ready = influx_push.ready?) || (max_wait && count >= max_wait)
      count += 1
      sleep 1
    end

    if ready
      logger.info 'InfluxDB is ready.'
      true
    else
      logger.error "InfluxDB not ready after #{count} seconds - aborting."
      false
    end
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
