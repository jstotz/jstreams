require 'set'
require 'concurrent/array'

RSpec.describe 'multiple subscribers' do
  after(:each) { Redis.new.flushdb }

  it 'receives each published message once' do
    published = 1000.times.map { |i| "msg#{i + 1}" }

    jstreams = Jstreams::Context.new

    Thread.new { published.each { |line| jstreams.publish('mystream', line) } }

    received = Concurrent::Array.new

    subscribers =
      3.times.map do
        jstreams.subscribe(
          'mysubscriber',
          'mystream'
        ) do |message, _stream, subscriber|
          received << message
          subscribers.each(&:stop) if received.size >= published.size
        end
      end

    Timeout.timeout(5) { jstreams.run }

    expect(received).to match_array(published)
  end
end
