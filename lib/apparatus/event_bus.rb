# frozen_string_literal: true

module Apparatus
  class EventBus
    def initialize
      @handlers = Hash.new { |hash, key| hash[key] = [] }
    end

    def on(event, &block)
      @handlers[event] << block
    end

    def emit(event, payload = {})
      @handlers[event].each { |handler| handler.call(payload) }
    end

    def handlers_for(event)
      @handlers[event].dup
    end

    def clear
      @handlers.clear
    end
  end
end
