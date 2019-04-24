require 'json'
require 'connection_pool'
require 'active_support/tagged_logging'

require_relative 'serializers/json'
require_relative 'publisher'
require_relative 'subscriber'

module Jstreams
  class Context
    attr_reader :redis_pool, :serializer, :logger

    def initialize(
      redis: {},
      serializer: Serializers::JSON.new,
      logger: Logger.new(ENV['JSTREAMS_VERBOSE'] ? STDOUT : File::NULL)
    )
      # TODO: configurable/smart default pool size
      @redis_pool =
        ::ConnectionPool.new(size: 10, timeout: 5) { Redis.new(redis) }
      @serializer = serializer
      logger.formatter ||= ::Logger::Formatter.new
      @logger = ::ActiveSupport::TaggedLogging.new(logger)
      @publisher =
        Publisher.new(
          redis_pool: @redis_pool, serializer: serializer, logger: @logger
        )
      @subscribers = []
    end

    def publish(stream, message)
      @publisher.publish(stream, message)
    end

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

    def unsubscribe(subscriber)
      @subscribers.delete(subscriber)
    end

    def run(wait: true)
      trap('INT') { shutdown }
      Thread.abort_on_exception = true
      @subscriber_threads =
        @subscribers.map { |subscriber| Thread.new { subscriber.run } }
      wait_for_shutdown if wait
    end

    def wait_for_shutdown
      @subscriber_threads.each(&:join)
    end

    def shutdown
      @subscribers.each(&:stop)
    end
  end
end
