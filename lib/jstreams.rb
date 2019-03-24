require 'redis'
require 'jstreams/version'
require 'jstreams/context'

module Jstreams
  def self.default_context
    @default_context ||= Context.new
  end

  class Error < StandardError; end
end
