require 'simplecov' # These two lines must go first
SimpleCov.start

$LOAD_PATH.unshift(File.expand_path('../app', __dir__))

require 'minitest/autorun'
require 'webmock/minitest'

# Support files
Dir["#{__dir__}/support/*.rb"].each { |file| require file }
