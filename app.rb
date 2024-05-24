#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

$LOAD_PATH.unshift(File.expand_path('./lib', __dir__))

require 'dotenv/load'
require 'loop'
require 'config'
require 'stdout_logger'

logger = StdoutLogger.new

logger.info 'MQTT collector for SOLECTRUS, ' \
              "Version #{ENV.fetch('VERSION', '<unknown>')}, " \
              "built at #{ENV.fetch('BUILDTIME', '<unknown>')}"
logger.info 'https://github.com/solectrus/mqtt-collector'
logger.info 'Copyright (c) 2023-2024 Georg Ledermann and contributors, released under the MIT License'
logger.info "\n"

config = Config.new(ENV, logger:)

logger.info "Using Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}"
logger.info "Subscribing from MQTT broker at #{config.mqtt_url}"
logger.info "Pushing to InfluxDB at #{config.influx_url}, " \
              "bucket #{config.influx_bucket}"
logger.info "\n"

mapper = Mapper.new(config:)
if mapper.topics.empty?
  logger.error 'No mappings defined - exiting.'
  exit 1
else
  logger.info "Subscribing to #{mapper.topics.length} topics:"
  max_length = mapper.topics.map(&:length).max
  mapper.topics.each do |topic|
    logger.info "- #{topic.ljust(max_length, ' ')} => #{mapper.formatted_mapping(topic)}"
  end
  logger.info "\n"
end

Loop.new(config:).start
