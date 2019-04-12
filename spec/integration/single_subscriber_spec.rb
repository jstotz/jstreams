require 'set'

RSpec.describe 'single subscriber' do
  before(:each) { Redis.new.flushdb }
  after(:each) { jstreams.shutdown }

  let(:jstreams) { Jstreams::Context.new }

  it 'receives each published message once' do
    published = Array.new(1000) { |i| "msg#{i + 1}" }

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

  it 'processes its own pending messages on restart' do
    jstreams.publish('mystream', 'foo')

    received = []

    subscriber =
      jstreams.subscribe(
        'mysubscriber',
        'mystream',
        key: 'myconsumer', error_handler: ->(*_args) {  }
      ) do |_message, _stream, subscr|
        subscr.stop
        raise 'fail'
      end

    Timeout.timeout(5) { jstreams.run }

    jstreams.unsubscribe(subscriber)

    # Resubscribe
    jstreams.subscribe(
      'mysubscriber',
      'mystream',
      key: 'myconsumer'
    ) do |message, _stream, subscr|
      subscr.stop
      received << message
    end

    Timeout.timeout(5) { jstreams.run }

    expect(received).to eq(%w[foo])
  end
end
