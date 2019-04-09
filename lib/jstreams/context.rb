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
      redis_url: nil,
      serializer: Serializers::JSON.new,
      logger: Logger.new(ENV['JSTREAMS_VERBOSE'] ? STDOUT : File::NULL)
    )
      # TODO: configurable/smart default pool size
      @redis_pool =
        ::ConnectionPool.new(size: 10, timeout: 5) { Redis.new(url: redis_url) }
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

    def subscribe(name, streams, key: name, error_handler: nil, &block)
      subscriber =
        Subscriber.new(
          redis_pool: @redis_pool,
          logger: @logger,
          serializer: @serializer,
          name: name,
          key: key,
          streams: Array(streams),
          handler: block,
          error_handler: error_handler
        )
      @subscribers << subscriber
      subscriber
    end

    def run
      Thread.abort_on_exception = true
      threads = @subscribers.map { |subscriber| Thread.new { subscriber.run } }
      threads.each(&:join)
    end
  end
end
