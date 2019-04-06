require 'set'

RSpec.describe 'single subscriber' do
  it 'receives each published message once' do
    published = 1000.times.map { |i| "msg#{i + 1}" }

    jstreams = Jstreams::Context.new

    Thread.new { published.each { |line| jstreams.publish('mystream', line) } }

    received = []

    jstreams.subscribe(
      'mysubscriber',
      'mystream'
    ) do |message, _stream, subscriber|
      received << message
      subscriber.stop if received.size == published.size
    end

    Timeout.timeout(5) { jstreams.run }

    expect(received).to eq(published)
  end
end
