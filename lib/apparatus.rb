# frozen_string_literal: true

require_relative "apparatus/version"

module Apparatus
  class Entity
    attr_accessor :components

    def initialize(components = {})
      @components = components
    end

    def [](key)
      components[key]
    end

    def []=(key, value)
      components[key] = value
    end

    def has?(*list)
      components.keys.to_set.intersection(list).size == list.size
    end
  end

  class System
    attr_reader :apparatus, :entities

    def initialize(apparatus, entities)
      raise TypeError, %{Expected 'apparatus' to be Apparatus::Body, got #{apparatus.class.inspect} instead} if !apparatus.is_a?(Apparatus::Body)
      raise TypeError, %{Expected 'entities' to be Array, got #{entities.class.inspect} instead} if !entities.is_a?(Array)

      @apparatus = apparatus
      @entities = entities
    end
  end

  class Body
    class SystemHierarchyError < StandardError; end

    attr_reader :entities, :systems

    def initialize
      @entities = []
      @systems = []
    end

    def add_system(system_class)
      raise NoMethodError, "Expected a public instance method 'run' to be defined, but it was not" if !system_class.public_instance_methods.include?(:run)

      raise SystemHierarchyError, "System is expected to extend 'Apparatus::System', but did not" if !(system_class < Apparatus::System)

      systems << system_class.new(self, entities)
    end

    def add_systems(*list)
      list.each { add_system(_1) }
    end

    def add_entity(entity)
      entities << entity
    end

    def add_entities(*list)
      list.each { add_entity(_1) }
    end

    def run
      systems.each(&:run)
    end
  end
end
