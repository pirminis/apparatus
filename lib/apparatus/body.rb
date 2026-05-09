# frozen_string_literal: true

module Apparatus
  class Body
    class SystemHierarchyError < StandardError; end
    class CircularDependencyError < StandardError; end
    class MissingDependencyError < StandardError; end

    attr_reader :entities, :systems, :component_index, :event_bus

    def initialize
      @entities = []
      @systems = []
      @component_index = Hash.new { |hash, key| hash[key] = Set.new }
      @next_id = 0
      @event_bus = EventBus.new
      @query_cache = {}
      @named_entities = {}
      @rel_index = Hash.new { |hash, key| hash[key] = Hash.new { |h2, k2| h2[k2] = Set.new } }
      @rel_by_type = Hash.new { |hash, key| hash[key] = Set.new }
    end

    def add_system(system_class)
      unless system_class < Apparatus::System
        raise SystemHierarchyError, "System is expected to extend 'Apparatus::System', but did not"
      end

      unless system_class.public_instance_methods(false).include?(:perform)
        raise NoMethodError, "Expected a public instance method 'perform' to be defined, but it was not"
      end

      systems << system_class
    end

    def add_systems(*list)
      list.each { |system| add_system(system) }
    end

    def remove_system(system_class)
      systems.delete(system_class)
    end

    def add_entity(entity)
      @next_id += 1
      entity.instance_variable_set(:@id, @next_id)
      entity.body = self
      entities << entity

      entity.components.each_key do |key|
        component_index[key] << entity
      end

      @named_entities[entity.name] = entity if entity.name

      invalidate_query_cache!
      emit(:entity_added, entity: entity)
      entity
    end

    def add_entities(*list)
      list.each { |entity| add_entity(entity) }
    end

    def remove_entity(entity)
      return unless entities.include?(entity)

      # Recursively remove children first (depth-first)
      children = query_relationship(:ChildOf, entity)
      children.each { |child| remove_entity(child) }

      # Clean up relationships where entity is source
      entity.relationships.each do |type, targets|
        targets.each do |target|
          @rel_index[type][target].delete(entity)
        end
        @rel_by_type[type].delete(entity)
      end

      # Clean up relationships where entity is target
      @rel_index.each do |type, target_map|
        next unless target_map.key?(entity)

        sources = target_map[entity].dup
        sources.each do |source|
          source.remove_relationship(type, entity) if source.is_a?(Entity) && source.body == self
        end
        target_map.delete(entity)
      end

      entity.components.each_key do |key|
        component_index[key].delete(entity)
      end

      entities.delete(entity)
      @named_entities.delete(entity.name) if entity.name
      entity.body = nil
      entity.instance_variable_set(:@id, nil)

      invalidate_query_cache!
      emit(:entity_removed, entity: entity)
      entity
    end

    def query(*keys)
      return [] if keys.empty?

      cache_key = keys.sort
      return @query_cache[cache_key].dup if @query_cache.key?(cache_key)

      result = if keys.size == 1
                 component_index[keys.first].to_a
               else
                 sets = keys.map { |key| component_index[key] }
                 intersection = sets.first.dup
                 sets[1..].each { |set| intersection &= set }
                 intersection.to_a
               end

      @query_cache[cache_key] = result
      result.dup
    end

    alias with query

    def create_entity(**components)
      entity = Entity.new(components)
      entity.name = components[:name] if components.key?(:name)
      add_entity(entity)
    end

    def create_prefab(**components)
      entity = Entity.new(components)
      entity.mark_as_prefab!
      entity.name = components[:name] if components.key?(:name)
      add_entity(entity)
    end

    def instantiate(prefab, **overrides)
      raise ArgumentError, "Expected a prefab entity" unless prefab.prefab?

      entity = Entity.new(overrides)
      entity.prefab_parent = prefab
      entity.name = overrides[:name] if overrides.key?(:name)
      add_entity(entity)
    end

    def lookup(name)
      @named_entities[name]
    end

    def query_relationship(rel, target = :*)
      if target == :*
        @rel_by_type[rel].to_a
      else
        @rel_index[rel][target].to_a
      end
    end

    def children_of(parent)
      query_relationship(:ChildOf, parent)
    end

    def run
      validate_dependencies!
      systems.each do |klass|
        system = klass.new(self)
        system.run
      end
    end

    def on(event, &)
      event_bus.on(event, &)
    end

    def emit(event, payload = {})
      event_bus.emit(event, payload)
    end

    def update_index(entity, component_key, action)
      case action
      when :component_added, :component_updated
        component_index[component_key] << entity
      when :component_removed
        component_index[component_key].delete(entity)
      end

      invalidate_query_cache!
    end

    def update_relationship_index(entity, type, target, action)
      case action
      when :added
        @rel_index[type][target] << entity
        @rel_by_type[type] << entity
      when :removed
        @rel_index[type][target].delete(entity)
        @rel_by_type[type].delete(entity) unless entity.relationships(type).any?
      end
    end

    private

    def invalidate_query_cache!
      @query_cache.clear
    end

    def validate_dependencies!
      klass_map = systems.to_h { |klass| [klass, true] }

      systems.each do |klass|
        klass.dependencies.each do |dep|
          raise MissingDependencyError, "#{klass} depends on #{dep}, but it was not added" unless klass_map[dep]
        end
      end

      visiting = {}
      visited = {}

      dfs = lambda do |klass|
        return false if visited[klass]
        return true if visiting[klass]

        visiting[klass] = true
        klass.dependencies.each do |dep|
          if dfs.call(dep)
            raise CircularDependencyError, "Circular dependency detected involving #{klass} and #{dep}"
          end
        end
        visiting[klass] = false
        visited[klass] = true

        false
      end

      systems.each { |klass| dfs.call(klass) }
    end
  end
end
