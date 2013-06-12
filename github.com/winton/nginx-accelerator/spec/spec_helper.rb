ENV['ENV'] = 'test'

require "bundler"
Bundler.require(:default, :development)

$root = File.expand_path('../../', __FILE__)
require "#{$root}/lib/accelerator"

Dir["#{$root}/spec/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
end