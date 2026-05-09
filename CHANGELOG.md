## [Unreleased]

## 0.3.0 - 2025-05-09

### Added

- **Relationships**: Entities can have relationships to other entities via `add_relationship(type, target)`. Query with `body.query_relationship(:Likes, alice)` or `body.query_relationship(:Likes, :*)`.
- **Hierarchies**: Built-in `ChildOf` relationship. `entity.child_of(parent)`, `entity.parent`, `body.children_of(parent)`. Removing a parent recursively removes all children.
- **Prefabs**: `body.create_prefab(**components)` creates template entities. `body.instantiate(prefab, **overrides)` creates instances that inherit components. Instances can override with `[]=`.
- **Named entities**: `entity.name` and `body.lookup(name)` for human-readable entity references.
- **Relationship events**: `:relationship_added`, `:relationship_removed` emitted automatically.

### Changed

- **Breaking**: Removed archetypes. `define_archetype` and `create_entity(:archetype_name)` are gone. Use `create_prefab` and `instantiate` instead.
- **Breaking**: `create_entity` now only takes `**components`.

## 0.2.0 - 2025-05-09

### Added

- **Entity IDs**: Every entity now receives a unique sequential `id` when added to a `Body`.
- **Component index**: `Body` maintains an internal index for O(1) single-component and O(min_set) multi-component queries.
- **Query API**: `body.query(:name, :price)` and `body.with(:name, :price)` return snapshot arrays of matching entities.
- **Entity removal**: `body.remove_entity(entity)` removes an entity and cleans up all indexes.
- **Component removal**: `entity.remove(:component)` removes a component and updates indexes.
- **System filtering**: Systems can declare `filter :name, :price` to receive only matching entities.
- **System exclusion**: Systems can declare `exclude :disabled` to skip entities with certain components.
- **System dependencies**: `depends_on OtherSystem` ensures validation.
- **System lifecycle hooks**: `#before_run` and `#after_run` are called around `#perform`.
- **Event bus**: `body.on(:event) { |payload| ... }` and `body.emit(:event, payload)` for decoupled communication.
- **Auto-events**: `:entity_added`, `:entity_removed`, `:component_added`, `:component_updated`, `:component_removed` are emitted automatically.
- **Query caching**: `Body#query` caches results and invalidates on structural changes.
- **CI**: GitHub Actions workflow for Ruby 3.2, 3.3, and 3.4.

### Changed

- **Breaking**: `System#initialize` now takes only `apparatus`. Systems access entities via `#entities` (filtered automatically).
- **Breaking**: `System#run` is now the framework entry point. User logic goes in `#perform`.
- **Breaking**: `Body#add_system` stores class references, not instances. Systems are instantiated fresh on each `Body#run`.
- **Breaking**: Systems run in chronological registration order. `priority` has been removed.
- **Performance**: `Entity#has?` no longer allocates a `Set` on every call.

## 0.1.2 - 2023-08-20

- Add basic tests
- Add rubocop gems
- Improve main logic (thanks tests)

## 0.1.1 - 2023-08-14

- Add source code for the apparatus
- Create meaningful README.md

## 0.1.0 - 2023-08-09

- Initial release
