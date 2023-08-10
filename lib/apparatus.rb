# frozen_string_literal: true

require_relative "apparatus/version"

class Apparatus
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
      @apparatus = apparatus
      @entities = entities
    end
  end

  attr_reader :entities, :systems

  def initialize
    @entities = []
    @systems = []
  end

  def add_system(system_class)
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
