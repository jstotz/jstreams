# frozen_string_literal: true

require 'bundler/setup'
require 'jstreams'

STDOUT.sync = true
logger = Logger.new(STDOUT)

logger.info 'Starting publisher...'

jstreams = Jstreams::Context.new logger: logger

loop do
  body = "hello #{Time.now}"
  id = jstreams.publish('mystream', body)
  logger.info "published: #{id} - #{body}"
  sleep(1)
end
