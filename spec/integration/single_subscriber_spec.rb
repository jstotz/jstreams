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

  it 'processes its own pending messages on restart' do
    jstreams = Jstreams::Context.new

    jstreams.publish('mystream', 'foo')

    received = []

    subscriber =
      jstreams.subscribe(
        'mysubscriber',
        'mystream',
        key: 'myconsumer', error_handler: ->(*_args) {  }
      ) do |_message, _stream, subscriber|
        subscriber.stop
        raise 'fail'
      end

    Timeout.timeout(5) { jstreams.run }

    jstreams.unsubscribe(subscriber)

    # Resubscribe
    jstreams.subscribe(
      'mysubscriber',
      'mystream',
      key: 'myconsumer'
    ) do |message, _stream, subscriber|
      subscriber.stop
      received << message
    end

    Timeout.timeout(5) { jstreams.run }

    expect(received).to eq(%w[foo])
  end
end
