module Jstreams
  class Publisher
    def initialize(redis:, serializer:)
      @redis = redis
      @serializer = serializer
    end

    def publish(stream, message)
      @redis.xadd(stream, payload: @serializer.serialize(message, stream))
    end
  end
end
