# frozen_string_literal: true

require 'json'
require 'connection_pool'

require_relative 'serializers/json'
require_relative 'publisher'
require_relative 'subscriber'
require_relative 'tagged_logging'

module Jstreams
  ##
  # A collection of jstreams subscribers, their associated threads, and an interface for
  # publishing messages.
  class Context
    attr_reader :redis_pool, :serializer, :logger

    ##
    # Initializes a jstreams context
    #
    # @param [String] redis_url Redis URL
    # @param [Serializer] serializer Message serializer
    # @param [Logger] logger Logger
    def initialize(
      redis_url: nil,
      serializer: Serializers::JSON.new,
      logger: Logger.new(ENV['JSTREAMS_VERBOSE'] ? STDOUT : File::NULL)
    )
      # TODO: configurable/smart default pool size
      @redis_pool =
        ::ConnectionPool.new(size: 10, timeout: 5) { Redis.new(url: redis_url) }
      @serializer = serializer
      @logger = TaggedLogging.new(logger)
      @publisher =
        Publisher.new(
          redis_pool: @redis_pool, serializer: serializer, logger: @logger
        )
      @subscribers = []
    end

    ##
    # Publishes a message to the given stream
    #
    # @param [String] stream Stream name
    # @param [Hash] message Message to publish
    def publish(stream, message)
      @publisher.publish(stream, message)
    end

    ##
    # Publishes a message to the given stream
    #
    # @param [String] name Subscriber name
    # @param [String] streams Stream name or array of stream names to follow
    # @param [String] key Unique consumer name
    #
    # @return [Subscriber] Handle to the registered subscriber. Can be used to #unsubscribe
    def subscribe(name, streams, key: name, **kwargs, &block)
      subscriber =
        Subscriber.new(
          redis_pool: @redis_pool,
          logger: @logger,
          serializer: @serializer,
          name: name,
          key: key,
          streams: Array(streams),
          handler: block,
          **kwargs
        )
      @subscribers << subscriber
      subscriber
    end

    ##
    # Unsubscribes the given subscriber
    #
    # @param [Subscriber] subscriber Subscriber to unsubscribe
    def unsubscribe(subscriber)
      @subscribers.delete(subscriber)
    end

    ##
    # Starts each registered subscriber
    #
    # @param [Boolean] wait Whether or not to block until subscribers shut down
    def run(wait: true)
      trap('INT') { shutdown }
      Thread.abort_on_exception = true
      @subscriber_threads =
        @subscribers.map { |subscriber| Thread.new { subscriber.run } }
      wait_for_shutdown if wait
    end

    ##
    # Blocks until all subscribers are shut down
    def wait_for_shutdown
      @subscriber_threads.each(&:join)
    end

    ##
    # Shuts down each registered subscriber
    def shutdown
      @subscribers.each(&:stop)
    end
  end
end
