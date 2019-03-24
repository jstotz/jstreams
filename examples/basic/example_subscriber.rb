require 'bundler/setup'
require 'logger'
require 'jstreams'

STDOUT.sync = true

USAGE = 'usage: ruby subscriber.rb [subscriber_key]'

subscriber_key = ARGV[0] || abort(USAGE)

puts "Starting subscriber #{subscriber_key}..."

logger = Logger.new(STDOUT)
jstreams = Jstreams::Context.new(logger: logger)

jstreams.subscribe(
  'mysubscriber',
  'mystream',
  key: subscriber_key
) { |message| logger.info "Subscriber got a message: #{message.inspect}" }

jstreams.run
