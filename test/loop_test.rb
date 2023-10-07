require 'test_helper'
require 'loop'

class LoopTest < Minitest::Test
  def mqtt_server
    @mqtt_server ||=
      begin
        server = MQTT::FakeServer.new(nil, '127.0.01')
        server.just_one_connection = true
        server.logger.level = Logger::WARN
        server
      end
  end

  def config
    @config ||=
      Config.from_env mqtt_host: mqtt_server.address,
                      mqtt_port: mqtt_server.port
  end

  def test_start
    mqtt_server.start(payload_to_publish: '80.0')

    out, _err =
      capture_io do
        VCR.use_cassette('influx_success') { Loop.start(config:, max_count: 1) }
      end

    assert_match(/{"bat_charge_current"=>80/, out)
  end
end
