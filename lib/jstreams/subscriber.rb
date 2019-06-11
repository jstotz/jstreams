# frozen_string_literal: true

require_relative 'consumer_group'

# :nodoc:
module Jstreams
  ##
  # Retrieves messages from the Redis consumer group and dispatches them
  # to the handler.
  class Subscriber
    ##
    # Returns a new instance of Subscriber
    def initialize(
      name:,
      key: name,
      streams:,
      redis_pool:,
      serializer:,
      handler:,
      logger:,
      error_handler: nil,
      abandoned_message_check_interval: ABANDONED_MESSAGE_CHECK_INTERVAL,
      abandoned_message_idle_timeout: ABANDONED_MESSAGE_IDLE_TIMEOUT
    )
      @name = name
      @key = key
      @streams = streams
      @redis_pool = redis_pool
      @serializer = serializer
      @handler = handler
      @error_handler = error_handler
      @logger = logger
      @abandoned_message_check_interval = abandoned_message_check_interval
      @abandoned_message_idle_timeout = abandoned_message_idle_timeout
      @need_to_check_own_pending = true
    end

    ##
    # Starts the subscriber's message handling loop.
    # Blocks until either a fatal error is raised or #stop is called
    def run
      # TODO: Mutex
      @running = true
      logger.tagged("subscriber:#{name}", "key:#{key}") do
        process_messages while @running
        logger.info 'Subscriber exiting run loop'
      end
    end

    ##
    # Stops the subscriber.
    def stop
      # TODO: Mutex
      logger.info 'Subscriber stopping'
      @running = false
    end

    private

    READ_TIMEOUT = 0.25 # seconds
    ABANDONED_MESSAGE_CHECK_INTERVAL = 10 # seconds
    ABANDONED_MESSAGE_IDLE_TIMEOUT = 600 # seconds
    ABANDONED_MESSAGE_BATCH_SIZE = 100

    attr_reader :name,
                :key,
                :logger,
                :handler,
                :streams,
                :redis_pool,
                :redis,
                :serializer,
                :abandoned_message_check_interval,
                :abandoned_message_idle_timeout

    alias consumer_group name
    alias consumer_name key

    def process_messages
      @redis_pool.with do |redis|
        @redis = redis
        results = read_messages
        verbose_logger.debug 'timed out waiting for messages' if results.empty?
        results.each do |stream, entries|
          entries.each do |id, entry|
            logger.tagged("stream:#{stream}", "id:#{id}") do
              handle_entry(stream, id, entry)
            end
          end
        end
      end
    end

    def read_messages
      verbose_logger.debug do
        "Reading messages (time to reclaim?: #{time_to_reclaim?}, last reclaim: #{@last_reclaim_time})"
      end
      return read_own_pending if @need_to_check_own_pending
      results = {}
      results.merge!(reclaim_abandoned_messages) if time_to_reclaim?
      results.merge!(read_group)
      results
    end

    def read_own_pending
      verbose_logger.debug 'Reading own pending entries'
      results = read_group(block: nil, id: 0)
      if results.values.any? { |entries| !entries.empty? }
        verbose_logger.debug { "Own pending entries: #{results}" }
      else
        verbose_logger.debug 'No pending entries'
        @need_to_check_own_pending = false
      end
      results
    end

    def reclaim_abandoned_messages
      verbose_logger.debug 'Looking for abandoned messages to reclaim'
      results = {}
      streams.each do |stream|
        results[stream] = reclaim_abandoned_messages_in_stream(stream)
      end
      @last_reclaim_time = Time.now
      verbose_logger.debug do
        "Done looking for abandoned messages to reclaim. Found: #{results
          .inspect}"
      end
      results
    rescue ::Redis::CommandError => e
      raise e unless e.message =~ /NOGROUP/
      logger.debug "Couldn't reclaim messages because group does not exist yet"
      {}
    end

    def reclaim_abandoned_messages_in_stream(stream)
      reclaim_ids = []
      # TODO: pagination & configurable batch size
      read_pending(stream, ABANDONED_MESSAGE_BATCH_SIZE).each do |pe|
        unless pe['consumer'] != consumer_name && abandoned_pending_entry?(pe)
          next
        end
        logger.info "Reclaiming abandoned message #{pe['entry_id']}" \
                      " from consumer #{pe['consumer']}"
        reclaim_ids << pe['entry_id']
      end

      return [] if reclaim_ids.empty?

      redis.xclaim(
        stream,
        consumer_group,
        consumer_name,
        (abandoned_message_idle_timeout * 1000).round,
        reclaim_ids
      )
    end

    def abandoned_pending_entry?(pending_entry)
      pending_entry['elapsed'] >= (abandoned_message_idle_timeout * 1000)
    end

    def read_pending(stream, count)
      xpending(stream, count)
    end

    def read_group(block: READ_TIMEOUT * 1000, id: '>')
      xreadgroup(block, id)
    rescue ::Redis::CommandError => e
      raise e unless e.message =~ /NOGROUP/
      create_consumer_groups
      retry
    end

    def time_to_reclaim?
      @last_reclaim_time.nil? ||
        (Time.now - @last_reclaim_time) >= abandoned_message_check_interval
    end

    def xpending(stream, count)
      verbose_logger.debug 'calling xpending'
      redis.xpending(stream, consumer_group, '-', '+', count)
    end

    def xreadgroup(block, id)
      verbose_logger.debug 'calling xreadgroup'
      redis.xreadgroup(
        consumer_group,
        consumer_name,
        streams,
        streams.map { id },
        block: block
      )
    end

    def handle_entry(stream, id, entry)
      logger.debug { "received raw entry: #{entry.inspect}" }
      begin
        handler.call(deserialize_entry(stream, id, entry), stream, self)
        logger.debug { "ACK message #{[stream, consumer_group, id].inspect}" }
        redis.xack(stream, consumer_group, id)
      rescue StandardError => e
        logger.debug do
          "Error processing message #{[
            stream,
            consumer_group,
            id
          ].inspect}: #{e}"
        end
        raise e if @error_handler.nil?
        @error_handler.call(e, stream, id, entry)
      end
    end

    def deserialize_entry(stream, id, entry)
      serializer.deserialize(entry['payload'], stream)
    rescue StandardError => e
      # TODO: Allow subscribers to register an error handler.
      # For now we'll just log and skip.
      logger.error "failed to deserialize entry #{id}: #{entry
                     .inspect} - error: #{e}"
    end

    def create_consumer_groups
      streams.each do |stream|
        group =
          ConsumerGroup.new(name: consumer_group, stream: stream, redis: redis)
        if group.create_if_not_exists
          logger.info "Created consumer group #{consumer_group} for stream #{stream}"
        else
          logger.info 'Consumer group already exists'
        end
      end
    end

    def verbose_logger
      @verbose_logger ||= (ENV['JSTREAMS_VERBOSE'] ? logger : Logger.new(IO::NULL))
    end
  end

  private_constant :Subscriber
end
