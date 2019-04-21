require 'json'
require_relative '../serializer'

module Jstreams
  module Serializers
    class JSON < Serializer
      def serialize(message, _stream)
        ::JSON.generate(message)
      end

      def deserialize(message, _stream)
        ::JSON.parse(message)
      end
    end
  end
end
