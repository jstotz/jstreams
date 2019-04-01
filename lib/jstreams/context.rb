require 'json'
require 'active_support/tagged_logging'

require_relative 'serializers/json'
require_relative 'publisher'
require_relative 'subscriber'

module Jstreams
  class Context
    attr_reader :redis, :serializer, :logger

    def initialize(
      redis: ::Redis.new,
      serializer: Serializers::JSON.new,
      logger: Logger.new(File::NULL)
    )
      @redis = redis
      @serializer = serializer
      @publisher = Publisher.new(redis: redis, serializer: serializer)
      logger.formatter ||= ::Logger::Formatter.new
      @logger = ::ActiveSupport::TaggedLogging.new(logger)
      @subscribers = []
    end

    def publish(stream, message)
      @publisher.publish(stream, message)
    end

    def subscribe(name, streams, key: name, &block)
      @subscribers.push(
        Subscriber.new(
          redis: @redis,
          logger: @logger,
          serializer: @serializer,
          name: name,
          key: key,
          streams: Array(streams),
          handler: block
        )
      )
    end

    def run
      Thread.abort_on_exception = true
      threads = @subscribers.map { |subscriber| Thread.new { subscriber.run } }
      threads.each(&:join)
    end
  end
end
