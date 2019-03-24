require 'bundler/setup'
require 'jstreams'

jstreams = Jstreams::Context.new(logger: Logger.new(STDOUT))

IO.readlines('../fixtures/random-sorted-1000.txt', chomp: true).each do |line|
  jstreams.publish('mystream', line)
end

jstreams.publish('mystream', '<end>')

sleep
