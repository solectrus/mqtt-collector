require 'mqtt'
require 'influxdb-client'
require 'influx_push'
require 'mapper'

RETRY_TIMEOUT = 5 # seconds

class Loop
  def self.start(config:, max_count: nil)
    new(config:, max_count:).start
  end

  def initialize(config:, max_count: nil)
    @config = config
    @max_count = max_count
  end

  attr_reader :config, :max_count

  def start
    subscribe_topics
    receive_messages
  rescue MQTT::ProtocolException, Errno::ECONNRESET => e
    handle_exception(e)

    retry
  end

  def subscribe_topics
    # Subscribe to all topics
    mapper.topics.each { |topic| mqtt_client.subscribe(topic) }
  end

  def receive_messages
    # (Mostly) endless loop to receive messages
    count = 0
    loop do
      time, fields = next_message
      influx_push.call(fields, time: time.to_i)

      count += 1
      break if max_count && count >= max_count
    end
  end

  def next_message
    topic, message = mqtt_client.get

    # There is no timestamp in the MQTT message, so we use the current time
    time = Time.now

    fields = mapper.call(topic, message)
    puts "#{time} topic=#{topic} message=#{message} => #{fields}"

    [time, fields]
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
    }
  end

  def mapper
    @mapper ||= Mapper.new(config:)
  end

  def handle_exception(error)
    puts "#{Time.now}: #{error}, will retry again in #{RETRY_TIMEOUT} seconds..."

    # Reset MQTT client, so it will reconnect next time
    @mqtt_client&.disconnect
    @mqtt_client = nil

    sleep(RETRY_TIMEOUT)
    # TODO: Use exponential backoff instead of fixed timeout
    # Maybe use this gem: https://github.com/kamui/retriable
  end
end
