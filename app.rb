#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

$LOAD_PATH.unshift(File.expand_path('./lib', __dir__))

require 'dotenv/load'
require 'loop'
require 'config'
require 'stdout_logger'
require 'app_version'

logger = StdoutLogger.new

logger.info 'MQTT collector for SOLECTRUS, ' \
              "Version #{AppVersion.current || '<unknown>'}, " \
              "built at #{ENV.fetch('BUILDTIME', '<unknown>')}"
logger.info 'https://github.com/solectrus/mqtt-collector'
logger.info 'Copyright (c) 2023-2026 Georg Ledermann and contributors, released under the MIT License'
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

if mapper.virtual_mappings.any?
  logger.info "Calculating #{mapper.virtual_mappings.length} virtual mapping(s):"
  mapper.virtual_mappings.each do |mapping|
    logger.info "- #{mapper.formatted_virtual_mapping(mapping)}"
  end
  logger.info "\n"
end

Loop.new(config:).start
