# frozen_string_literal: true

require 'logger'

##
# This is ActiveSupport::TaggedLogging extracted from the activesupport gem
# and adopted to be used in environments without activesupport's core extensions.
module Jstreams
  # :nodoc:
  module TaggedLogging
    # :nodoc:
    module Formatter
      def call(severity, timestamp, progname, msg)
        super(severity, timestamp, progname, "#{tags_text}#{msg}")
      end

      def tagged(*tags)
        new_tags = push_tags(*tags)
        yield self
      ensure
        pop_tags(new_tags.size)
      end

      def push_tags(*tags)
        tags.flatten.reject(&:nil?).reject(&:empty?).tap do |new_tags|
          current_tags.concat new_tags
        end
      end

      def pop_tags(size = 1)
        current_tags.pop size
      end

      def clear_tags!
        current_tags.clear
      end

      def current_tags
        # We use our object ID here to avoid conflicting with other instances
        thread_key = @thread_key ||= "jstreams_tagged_logging_tags:#{object_id}"
        Thread.current[thread_key] ||= []
      end

      def tags_text
        tags = current_tags
        if tags.one?
          "[#{tags[0]}] "
        elsif tags.any?
          tags.collect { |tag| "[#{tag}] " }.join
        end
      end
    end

    def self.new(logger)
      logger = logger.dup

      logger.formatter =
        if logger.formatter
          logger.formatter.dup
        else
          # Ensure we set a default formatter so we aren't extending nil!
          ::Logger::Formatter.new
        end

      logger.formatter.extend Formatter
      logger.extend(self)
    end

    %i[push_tags pop_tags clear_tags!].each do |method_name|
      define_method(method_name) do |*args, &block|
        formatter.send(method_name, *args, &block)
      end
    end

    def tagged(*tags)
      formatter.tagged(*tags) { yield self }
    end

    def flush
      clear_tags!
      super if defined?(super)
    end
  end

  private_constant :TaggedLogging
end
