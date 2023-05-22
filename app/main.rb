#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('.', __dir__))

require 'dotenv/load'
require 'loop'
require 'config'

# Flush output immediately
$stdout.sync = true

puts 'MQTT collector for SOLECTRUS, ' \
       "Version #{ENV.fetch('VERSION', '<unknown>')}, " \
       "built at #{ENV.fetch('BUILDTIME', '<unknown>')}"
puts 'https://github.com/solectrus/mqtt-collector'
puts 'Copyright (c) 2023 Georg Ledermann and contributors, released under the MIT License'
puts "\n"

config = Config.from_env

puts "Using Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}"
puts "Subscribing from MQTT broker at #{config.mqtt_url}"
puts "Pushing to InfluxDB at #{config.influx_url}, bucket #{config.influx_bucket}"
puts "\n"

Loop.start(config:)
