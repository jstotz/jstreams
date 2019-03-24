require 'bundler/setup'
require 'jstreams'
require 'rspec/expectations'
require 'timeout'

include RSpec::Matchers

jstreams = Jstreams::Context.new(logger: Logger.new(STDOUT))

results = []

jstreams.subscribe(
  'mysubscriber',
  'mystream',
  key: ARGV[0]
) do |message, _stream, subscriber|
  message == '<end>' ? subscriber.stop : results << message
end

Timeout.timeout(5) { jstreams.run }

expected = IO.readlines('../fixtures/random-sorted-1000.txt', chomp: true)

expect(results.sort).to eq(expected)
