# frozen_string_literal: true

require 'set'
require 'concurrent/array'
require 'concurrent/hash'

RSpec.describe 'multiple subscribers' do
  before(:each) { Redis.new.flushdb }
  after(:each) { jstreams.shutdown }

  let(:jstreams) { Jstreams::Context.new }

  it 'receives each published message once' do
    published = Array.new(1000) { |i| "msg#{i + 1}" }

    Thread.new { published.each { |line| jstreams.publish('mystream', line) } }

    received = Concurrent::Array.new

    subscribers =
      Array.new(3) do |i|
        jstreams.subscribe(
          'mysubscriber',
          'mystream',
          key: "consumer#{i}"
        ) do |message, _stream, _subscriber|
          received << message
          subscribers.each(&:stop) if received.size >= published.size
        end
      end

    Timeout.timeout(5) { jstreams.run }

    expect(received).to match_array(published)
  end

  context 'when a subscriber stops gracefully' do
    it 'reallocates any claimed work to the other subscribers' do
      published = Array.new(1000) { |i| "msg#{i + 1}" }

      received_by_consumer = Concurrent::Hash.new { |h, k| h[k] = [] }

      # This subscriber claims some messages but doesn't ack them
      jstreams.subscribe(
        'mysubscriber',
        'mystream',
        key: 'consumer-stopped',
        error_handler:
          ->(err, _, _, _) { jstreams.logger.debug "Ignoring error: #{err}" }
      ) do |_message, _stream, subscriber|
        subscriber.stop
        raise 'fail'
      end

      # These subscribers should pick up the work left behind
      subscribers =
        Array.new(3) do |i|
          consumer_key = "consumer-#{i}"
          jstreams.subscribe(
            'mysubscriber',
            'mystream',
            key: consumer_key,
            abandoned_message_check_interval: 0.25,
            abandoned_message_idle_timeout: 0.25
          ) do |message, _stream, _subscriber|
            received_by_consumer[consumer_key] << message
            total_received_count =
              received_by_consumer.values.map(&:size).reduce(:+)
            subscribers.each(&:stop) if total_received_count >= published.size
          end
        end

      # Starts the subscriber threads in the background
      jstreams.run(wait: false)

      # Publish the messages
      published.each { |line| jstreams.publish('mystream', line) }

      begin
        Timeout.timeout(5) { jstreams.wait_for_shutdown }
      rescue Timeout::Error
        raise "Timed out. Received #{received_by_consumer.map do |key, values|
                "#{key}: #{values.size}"
              end} (total: #{received_by_consumer.values.map(&:size).reduce(
                :+
              )})"
      end

      expect(received_by_consumer.values.flatten.uniq).to match_array(published)
    end
  end

  context 'when a subscriber stops unexpectedly' do
    it 'reallocates any claimed work to the other subscribers' do
      published = Array.new(1000) { |i| "msg#{i + 1}" }

      received_by_consumer = Concurrent::Hash.new { |h, k| h[k] = [] }

      # This subscriber claims some messages but doesn't ack them
      jstreams.subscribe(
        'mysubscriber',
        'mystream',
        key: 'consumer-stopped'
      ) { |_message, _stream, _subscriber| Thread.current.kill }

      # These subscribers should pick up the work left behind
      subscribers =
        Array.new(3) do |i|
          consumer_key = "consumer-#{i}"
          jstreams.subscribe(
            'mysubscriber',
            'mystream',
            key: consumer_key,
            abandoned_message_check_interval: 0.25,
            abandoned_message_idle_timeout: 0.25
          ) do |message, _stream, _subscriber|
            received_by_consumer[consumer_key] << message
            total_received_count =
              received_by_consumer.values.map(&:size).reduce(:+)
            subscribers.each(&:stop) if total_received_count >= published.size
          end
        end

      # Starts the subscriber threads in the background
      jstreams.run(wait: false)

      # Publish the messages
      published.each { |line| jstreams.publish('mystream', line) }

      begin
        Timeout.timeout(5) { jstreams.wait_for_shutdown }
      rescue Timeout::Error
        raise "Timed out. Received #{received_by_consumer.map do |key, values|
                "#{key}: #{values.size}"
              end} (total: #{received_by_consumer.values.map(&:size).reduce(
                :+
              )})"
      end

      expect(received_by_consumer.values.flatten.uniq).to match_array(published)
    end
  end
end
