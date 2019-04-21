# frozen_string_literal: true

require 'redis'

# :nodoc:
module Jstreams
  ##
  # A Redis streams Consumer Group
  class ConsumerGroup
    ##
    # @param [String] name Consumer group name
    # @param [String] stream Stream name
    # @param [Redis] redis Redis connection
    def initialize(name:, stream:, redis:)
      @name = name
      @stream = stream
      @redis = redis
    end

    ##
    # Returns true if the group was created and false if it already existed
    def create_if_not_exists(start_id: 0)
      @redis.xgroup(:create, @stream, @name, start_id, mkstream: true)
      true
    rescue ::Redis::CommandError => e
      raise e unless /BUSYGROUP/ =~ e.message
      false
    end
  end

  private_constant :ConsumerGroup
end
