# frozen_string_literal: true

require 'json'
require_relative '../serializer'

module Jstreams
  module Serializers
    ##
    # Simple JSON serializer
    class JSON < Serializer
      ##
      # Serializes the given message to a JSON string
      #
      # @param [Hash] message Message to serialize
      # @param [String] _stream Destination stream name (unused)
      #
      # @return [String] The JSON serialized message
      def serialize(message, _stream)
        ::JSON.generate(message)
      end

      ##
      # Deserializes the given JSON message to a Hash
      #
      # @param [Hash] message Message to deserialize
      # @param [String] _stream Source stream name (unused)
      #
      # @return [Hash] The deserialized message
      def deserialize(message, _stream)
        ::JSON.parse(message)
      end
    end
  end
end
