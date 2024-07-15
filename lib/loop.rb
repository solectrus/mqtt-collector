require 'mqtt'
require 'influxdb-client'
require 'influx_push'
require 'mapper'

class Loop
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:, retry_wait: 5, max_count: nil)
    @config = config
    @max_count = max_count
    @retry_wait = retry_wait
  end

  attr_reader :config, :max_count, :retry_wait

  def start
    subscribe_topics
    receive_messages
  rescue MQTT::ProtocolException, StandardError => e
    handle_exception(e)

    sleep(retry_wait)
    # TODO: Use exponential backoff instead of fixed timeout
    # Maybe use this gem: https://github.com/kamui/retriable

    retry if max_count.nil?
  rescue SystemExit, Interrupt
    logger.warn 'Exiting...'
  end

  def stop
    mqtt_client&.disconnect
  rescue MQTT::ProtocolException, StandardError => e
    handle_exception(e)
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
      influx_push.call(records, time: time.to_i)

      count += 1
      break if max_count && count >= max_count
    end
  end

  def next_message
    topic, message = mqtt_client.get

    # There is no timestamp in the MQTT message, so we use the current time
    time = Time.now

    records = mapper.records_for(topic, message)

    # Log all the data we received
    logger.info "# Message from #{time}"
    logger.info "  topic = #{topic}"
    logger.info "  message = #{message}"

    # Log all the data we are going to push to InfluxDB
    records.each do |record|
      logger.info "  => #{record[:measurement]}:#{record[:field]} = #{record[:value]}"
    end

    [time, records]
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
