require 'cheetah'
require 'pry'
require 'webmock/rspec'
require 'webmock/http_lib_adapters/curb_adapter'

Dir[Pathname.new(File.expand_path('../support', __FILE__)).join('**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.include RequestStubs
end
