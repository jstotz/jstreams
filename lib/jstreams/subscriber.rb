module Jstreams
  class Subscriber
    def initialize(
      name:,
      key: name,
      streams:,
      redis_pool:,
      serializer:,
      handler:,
      logger:,
      error_handler: nil
    )
      @name = name
      @key = key
      @streams = streams
      @redis_pool = redis_pool
      @serializer = serializer
      @handler = handler
      @error_handler = error_handler
      @logger = logger
    end

    def run
      # TODO: Mutex
      @running = true
      logger.tagged("subscriber:#{name}", "key:#{key}") do
        process_messages while @running
        logger.info 'Subscriber exiting run loop'
      end
    end

    def stop
      # TODO: Mutex
      logger.info 'Subscriber stopping'
      @running = false
    end

    private

    READ_TIMEOUT_MS = 250

    attr_reader :name, :key, :logger, :handler, :streams, :redis, :serializer

    alias_method :consumer_group, :name
    alias_method :consumer_name, :key

    def process_messages
      @redis_pool.with do |redis|
        @redis = redis
        results = read_group
        logger.debug 'timed out waiting for messages' if results.empty?
        results.each do |stream, entries|
          entries.each do |id, entry|
            logger.tagged("stream:#{stream}", "id:#{id}") do
              handle_entry(stream, id, entry)
            end
          end
        end
      end
    end

    def read_group
      logger.debug 'calling xreadgroup'
      results =
        redis.xreadgroup(
          consumer_group,
          consumer_name,
          streams,
          streams.map { '>' },
          block: READ_TIMEOUT_MS
        )
    rescue ::Redis::CommandError => e
      if e.message =~ /NOGROUP/
        create_consumer_groups
        retry
      end
      raise
    end

    def handle_entry(stream, id, entry)
      logger.debug { "received raw entry: #{entry.inspect}" }
      begin
        handler.call(deserialize_entry(stream, id, entry), stream, self)
        redis.xack(stream, consumer_group, id)
      rescue => e
        raise e if @error_handler.nil?
        @error_handler.call(e, stream, id, entry)
      end
    end

    def deserialize_entry(stream, id, entry)
      serializer.deserialize(entry['payload'], stream)
    rescue => e
      # TODO: Allow subscribers to register an error handler.
      # For now we'll just log and skip.
      logger.error "failed to deserialize entry #{id}: #{entry
                     .inspect} - error: #{e}"
    end

    def create_consumer_groups
      streams.each do |stream|
        begin
          logger.info "Creating consumer group #{consumer_group} for stream #{stream}"
          redis.xgroup(:create, stream, consumer_group, 0, mkstream: true)
        rescue ::Redis::CommandError => e
          if e.message =~ /BUSYGROUP/
            logger.info 'Consumer group already exists'
          end
        end
      end
    end
  end
end
