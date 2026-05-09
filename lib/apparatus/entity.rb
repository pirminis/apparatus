# frozen_string_literal: true

module Apparatus
  class Entity
    attr_reader :id, :components
    attr_accessor :body, :name, :prefab_parent

    def initialize(components = {})
      @components = components
      @id = nil
      @body = nil
      @name = nil
      @relationships = Hash.new { |hash, key| hash[key] = Set.new }
      @prefab_parent = nil
      @is_prefab = false
    end

    def [](key)
      if components.key?(key)
        components[key]
      elsif prefab_instance?
        @prefab_parent[key]
      end
    end

    def []=(key, value)
      old_exists = components.key?(key)
      components[key] = value

      if @id && body
        event = old_exists ? :component_updated : :component_added
        body.update_index(self, key, event)
        body.emit(event, entity: self, component: key)
      end

      components[key]
    end

    def add(key, value)
      self[key] = value
    end

    def remove(key)
      components.delete(key).tap do
        if @id && body
          body.update_index(self, key, :component_removed)
          body.emit(:component_removed, entity: self, component: key)
        end
      end
    end

    def has?(*list)
      list.all? { |key| components.key?(key) }
    end

    def owns?(key)
      components.key?(key)
    end

    def add_relationship(type, target)
      raise ArgumentError, "Target must be an Entity" unless target.is_a?(Entity)

      @relationships[type] << target

      if @id && body
        body.update_relationship_index(self, type, target, :added)
        body.emit(:relationship_added, entity: self, relationship: type, target: target)
      end

      target
    end

    def remove_relationship(type, target = nil)
      if target
        @relationships[type].delete(target).tap do
          if @id && body
            body.update_relationship_index(self, type, target, :removed)
            body.emit(:relationship_removed, entity: self, relationship: type, target: target)
          end
        end
      else
        targets = @relationships[type].to_a
        targets.each { |t| remove_relationship(type, t) }
      end
    end

    # rubocop:disable Naming/PredicateName
    def has_relationship?(type, target = nil)
      if target
        @relationships[type].include?(target)
      else
        @relationships.key?(type) && @relationships[type].any?
      end
    end
    # rubocop:enable Naming/PredicateName

    def relationships(type = nil)
      if type
        @relationships[type].to_a
      else
        @relationships.transform_values(&:to_a)
      end
    end

    def child_of(parent)
      add_relationship(:ChildOf, parent)
    end

    def parent
      relationships(:ChildOf).first
    end

    def mark_as_prefab!
      @is_prefab = true
    end

    def prefab?
      @is_prefab == true
    end

    def prefab_instance?
      !@prefab_parent.nil?
    end
  end
end
