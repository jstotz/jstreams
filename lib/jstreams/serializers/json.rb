# frozen_string_literal: true

require 'json'
require_relative '../serializer'

module Jstreams
  module Serializers
    ##
    # Simple JSON serializer
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
