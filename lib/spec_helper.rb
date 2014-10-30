#!ruby

require 'rspec/collection_matchers'

RSpec.configure do |config|
    config.expect_with :rspec do |c|
        c.syntax = [:should, :expect]
    end
end

if ENV['TEST_DEBUG'] and ENV['TEST_DEBUG'].length > 0
    $debug = (ENV['TEST_DEBUG'].to_i == 0 ? 2 : ENV['TEST_DEBUG'].to_i)
else
    $debug = 0
end

$server = 'ncc-api'
$api = '/ncc_api/v2'
$opt = { 'ncc' => { 'url' => "http://#{$server}#{$api}"}, 'debug' => $debug }
