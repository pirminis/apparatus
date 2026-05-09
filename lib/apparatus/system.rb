# frozen_string_literal: true

module Apparatus
  class System
    attr_reader :apparatus

    class << self
      def filter(*components)
        @filter_components = components
      end

      def exclude(*components)
        @exclude_components = components
      end

      def depends_on(*system_classes)
        @dependencies = system_classes
      end

      def filter_components
        @filter_components || []
      end

      def exclude_components
        @exclude_components || []
      end

      def dependencies
        @dependencies || []
      end
    end

    def initialize(apparatus)
      raise TypeError, "Expected 'apparatus' to be Apparatus::Body, got #{apparatus.class.inspect} instead" unless apparatus.is_a?(Apparatus::Body)

      @apparatus = apparatus
    end

    def entities
      result = if self.class.filter_components.any?
                 apparatus.query(*self.class.filter_components)
               else
                 apparatus.entities
               end

      if self.class.exclude_components.any?
        result = result.reject { |entity| self.class.exclude_components.any? { |key| entity.has?(key) } }
      end

      result
    end

    def run
      before_run
      perform
      after_run
    end

    def before_run; end

    def after_run; end

    def perform
      raise NoMethodError, "Expected a public instance method 'perform' to be defined, but it was not"
    end
  end
end
