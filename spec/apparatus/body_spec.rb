RSpec.describe Apparatus::Body do
  let(:test_system_class) do
    Class.new(Apparatus::System) do
      def perform; end
    end
  end

  describe "#initialize" do
    it "creates an instance" do
      body = described_class.new

      expect(body.entities).to be_a(Array)
      expect(body.entities).to be_empty
      expect(body.systems).to be_a(Array)
      expect(body.systems).to be_empty
      expect(body.component_index).to be_a(Hash)
      expect(body.event_bus).to be_a(Apparatus::EventBus)
    end
  end

  describe "#add_system" do
    it "adds a system class" do
      body = described_class.new
      klass = test_system_class

      expect { body.add_system(klass) }.to change { body.systems.size }.from(0).to(1)
    end

    it "raises error if system has no #perform method" do
      body = described_class.new
      bad_klass = Class.new(Apparatus::System)

      expect { body.add_system(bad_klass) }.to raise_error(NoMethodError, /perform/)
    end

    it "raises error if 'Apparatus::System' is not in the class hierarchy" do
      body = described_class.new
      bad_klass = Class.new { def perform; end }

      expect { body.add_system(bad_klass) }.to raise_error(Apparatus::Body::SystemHierarchyError)
    end
  end

  describe "#add_systems" do
    it "adds multiple systems" do
      body = described_class.new
      klass1 = test_system_class
      klass2 = Class.new(Apparatus::System) { def perform; end }

      expect { body.add_systems(klass1, klass2) }.to change { body.systems.size }.from(0).to(2)
    end
  end

  describe "#remove_system" do
    it "removes a system class" do
      body = described_class.new
      klass = test_system_class
      body.add_system(klass)

      expect { body.remove_system(klass) }.to change { body.systems.size }.from(1).to(0)
    end
  end

  describe "#add_entity" do
    it "adds an entity" do
      body = described_class.new
      entity = Apparatus::Entity.new(name: "John", age: 100)

      expect { body.add_entity(entity) }.to change { body.entities.size }.from(0).to(1)
    end

    it "assigns an id" do
      body = described_class.new
      entity = body.create_entity(name: "John")

      expect(entity.id).to eq(1)
    end

    it "assigns sequential ids" do
      body = described_class.new
      entity1 = body.create_entity(name: "John")
      entity2 = body.create_entity(name: "Jane")

      expect(entity1.id).to eq(1)
      expect(entity2.id).to eq(2)
    end

    it "sets body reference" do
      body = described_class.new
      entity = Apparatus::Entity.new(name: "John")
      body.add_entity(entity)

      expect(entity.body).to eq(body)
    end

    it "indexes components" do
      body = described_class.new
      body.create_entity(name: "John", age: 100)

      expect(body.query(:name).size).to eq(1)
      expect(body.query(:age).size).to eq(1)
    end

    it "registers named entities" do
      body = described_class.new
      body.create_entity(name: "user_42")

      expect(body.lookup("user_42")).to be_a(Apparatus::Entity)
    end

    it "emits entity_added event" do
      body = described_class.new
      events = []
      body.on(:entity_added) { |payload| events << payload }

      entity = body.create_entity(name: "John")

      expect(events).to contain_exactly(hash_including(entity: entity))
    end
  end

  describe "#add_entities" do
    it "adds multiple entities" do
      body = described_class.new
      person = Apparatus::Entity.new(name: "John", age: 100)
      table = Apparatus::Entity.new(name: "Table", color: "brown")

      expect { body.add_entities(person, table) }.to change { body.entities.size }.from(0).to(2)
    end
  end

  describe "#remove_entity" do
    it "removes an entity" do
      body = described_class.new
      entity = body.create_entity(name: "John")

      expect { body.remove_entity(entity) }.to change { body.entities.size }.from(1).to(0)
    end

    it "clears the entity's id" do
      body = described_class.new
      entity = body.create_entity(name: "John")
      body.remove_entity(entity)

      expect(entity.id).to be_nil
    end

    it "clears the entity's body reference" do
      body = described_class.new
      entity = body.create_entity(name: "John")
      body.remove_entity(entity)

      expect(entity.body).to be_nil
    end

    it "removes from component index" do
      body = described_class.new
      entity = body.create_entity(name: "John", age: 100)
      body.remove_entity(entity)

      expect(body.query(:name)).to be_empty
      expect(body.query(:age)).to be_empty
    end

    it "unregisters named entity" do
      body = described_class.new
      entity = body.create_entity(name: "John")
      body.remove_entity(entity)

      expect(body.lookup("John")).to be_nil
    end

    it "emits entity_removed event" do
      body = described_class.new
      entity = body.create_entity(name: "John")
      events = []
      body.on(:entity_removed) { |payload| events << payload }

      body.remove_entity(entity)

      expect(events).to contain_exactly(hash_including(entity: entity))
    end

    it "returns the entity" do
      body = described_class.new
      entity = body.create_entity(name: "John")

      expect(body.remove_entity(entity)).to eq(entity)
    end

    it "does nothing for non-existent entity" do
      body = described_class.new
      entity = Apparatus::Entity.new(name: "John")

      expect { body.remove_entity(entity) }.not_to(change { body.entities.size })
    end

    it "recursively removes children" do
      body = described_class.new
      parent = body.create_entity(name: "Parent")
      child = body.create_entity(name: "Child")
      grandchild = body.create_entity(name: "Grandchild")

      child.child_of(parent)
      grandchild.child_of(child)

      body.remove_entity(parent)

      expect(body.entities).to be_empty
    end

    it "cleans up incoming relationships" do
      body = described_class.new
      alice = body.create_entity(name: "Alice")
      bob = body.create_entity(name: "Bob")
      bob.add_relationship(:Likes, alice)

      body.remove_entity(alice)

      expect(bob.has_relationship?(:Likes)).to eq(false)
    end
  end

  describe "#query" do
    it "returns entities with a single component" do
      body = described_class.new
      body.create_entity(name: "John", age: 100)
      body.create_entity(name: "Jane")
      body.create_entity(price: 10)

      result = body.query(:name)

      expect(result.size).to eq(2)
      expect(result.map { |e| e[:name] }).to contain_exactly("John", "Jane")
    end

    it "returns entities with all specified components" do
      body = described_class.new
      body.create_entity(name: "John", age: 100, color: "red")
      body.create_entity(name: "Jane", age: 200)
      body.create_entity(price: 10)

      result = body.query(:name, :age)

      expect(result.size).to eq(2)
    end

    it "returns empty array for no matches" do
      body = described_class.new
      body.create_entity(name: "John")

      expect(body.query(:missing)).to be_empty
    end

    it "returns empty array for empty query" do
      body = described_class.new
      body.create_entity(name: "John")

      expect(body.query).to be_empty
    end

    it "returns a snapshot, not a live view" do
      body = described_class.new
      entity = body.create_entity(name: "John")
      result = body.query(:name)

      entity.remove(:name)

      expect(result.size).to eq(1)
      expect(body.query(:name)).to be_empty
    end

    it "caches queries and invalidates on changes" do
      body = described_class.new
      body.create_entity(name: "John", age: 100)

      first = body.query(:name, :age)
      second = body.query(:name, :age)

      expect(first).to eq(second)

      body.create_entity(name: "Jane", age: 200)
      third = body.query(:name, :age)

      expect(third.size).to eq(2)
    end

    it "normalizes cache key so order does not matter" do
      body = described_class.new
      body.create_entity(name: "John", age: 100)

      expect(body.query(:name, :age)).to eq(body.query(:age, :name))
    end
  end

  describe "#with" do
    it "is an alias for #query" do
      body = described_class.new
      body.create_entity(name: "John")

      expect(body.with(:name)).to eq(body.query(:name))
    end
  end

  describe "#create_entity" do
    it "creates an entity with components" do
      body = described_class.new
      entity = body.create_entity(name: "John", age: 100)

      expect(entity[:name]).to eq("John")
      expect(entity[:age]).to eq(100)
      expect(entity.id).not_to be_nil
    end

    it "does not create archetypes" do
      body = described_class.new

      expect(body).not_to respond_to(:define_archetype)
    end
  end

  describe "#create_prefab" do
    it "creates a prefab entity" do
      body = described_class.new
      prefab = body.create_prefab(name: "Spaceship", defense: 50)

      expect(prefab.prefab?).to eq(true)
      expect(prefab[:defense]).to eq(50)
    end
  end

  describe "#instantiate" do
    it "creates an instance from a prefab" do
      body = described_class.new
      prefab = body.create_prefab(defense: 50, health: 100)
      instance = body.instantiate(prefab)

      expect(instance.prefab_instance?).to eq(true)
      expect(instance[:defense]).to eq(50)
      expect(instance[:health]).to eq(100)
    end

    it "allows overriding components" do
      body = described_class.new
      prefab = body.create_prefab(defense: 50)
      instance = body.instantiate(prefab, defense: 75)

      expect(instance[:defense]).to eq(75)
      expect(instance.owns?(:defense)).to eq(true)
    end

    it "raises for non-prefab" do
      body = described_class.new
      regular = body.create_entity(name: "Regular")

      expect { body.instantiate(regular) }.to raise_error(ArgumentError, /prefab/)
    end

    it "inherits from prefab variants" do
      body = described_class.new
      spaceship = body.create_prefab(defense: 50, health: 100)
      freighter = body.create_prefab(health: 150)
      freighter.prefab_parent = spaceship
      instance = body.instantiate(freighter)

      expect(instance[:defense]).to eq(50)
      expect(instance[:health]).to eq(150)
    end
  end

  describe "#lookup" do
    it "finds entity by name" do
      body = described_class.new
      entity = body.create_entity(name: "user_42", type: "user")

      expect(body.lookup("user_42")).to eq(entity)
    end

    it "returns nil for missing name" do
      body = described_class.new

      expect(body.lookup("missing")).to be_nil
    end
  end

  describe "#query_relationship" do
    it "returns entities with relationship to specific target" do
      body = described_class.new
      alice = body.create_entity(name: "Alice")
      bob = body.create_entity(name: "Bob")
      charlie = body.create_entity(name: "Charlie")
      bob.add_relationship(:Likes, alice)
      charlie.add_relationship(:Likes, alice)

      result = body.query_relationship(:Likes, alice)

      expect(result).to contain_exactly(bob, charlie)
    end

    it "returns entities with relationship to any target" do
      body = described_class.new
      alice = body.create_entity(name: "Alice")
      pizza = body.create_entity(name: "Pizza")
      bob = body.create_entity(name: "Bob")
      bob.add_relationship(:Likes, alice)
      bob.add_relationship(:Eats, pizza)

      likers = body.query_relationship(:Likes, :*)
      eaters = body.query_relationship(:Eats, :*)

      expect(likers).to contain_exactly(bob)
      expect(eaters).to contain_exactly(bob)
    end

    it "returns empty array for no matches" do
      body = described_class.new

      expect(body.query_relationship(:Likes, :*)).to be_empty
    end
  end

  describe "#children_of" do
    it "returns children of a parent" do
      body = described_class.new
      parent = body.create_entity(name: "Parent")
      child1 = body.create_entity(name: "Child1")
      child2 = body.create_entity(name: "Child2")

      child1.child_of(parent)
      child2.child_of(parent)

      expect(body.children_of(parent)).to contain_exactly(child1, child2)
    end
  end

  describe "#run" do
    it "runs systems in chronological registration order" do
      body = described_class.new
      log = []

      klass_a = Class.new(Apparatus::System) do
        define_method(:perform) { log << :a }
      end

      klass_b = Class.new(Apparatus::System) do
        define_method(:perform) { log << :b }
      end

      klass_x = Class.new(Apparatus::System) do
        define_method(:perform) { log << :x }
      end

      body.add_systems(klass_a, klass_b, klass_x)
      body.run

      expect(log).to eq(%i(a b x))
    end

    it "passes filtered entities to systems" do
      body = described_class.new
      body.create_entity(name: "John", price: 10)
      body.create_entity(name: "Jane")
      body.create_entity(price: 20)

      captured = []
      klass = Class.new(Apparatus::System) do
        filter :name, :price
        define_method(:perform) do
          captured.concat(entities.map { |e| e[:name] })
        end
      end

      body.add_system(klass)
      body.run

      expect(captured).to eq(["John"])
    end

    it "passes excluded entities to systems" do
      body = described_class.new
      body.create_entity(name: "John", price: 10)
      body.create_entity(name: "Jane", price: 20, disabled: true)
      body.create_entity(price: 30)

      captured = []
      klass = Class.new(Apparatus::System) do
        filter :name, :price
        exclude :disabled
        define_method(:perform) do
          captured.concat(entities.map { |e| e[:name] })
        end
      end

      body.add_system(klass)
      body.run

      expect(captured).to eq(["John"])
    end

    it "validates dependencies" do
      body = described_class.new
      missing = Class.new(Apparatus::System) { def perform; end }

      klass = Class.new(Apparatus::System) do
        depends_on missing
        def perform; end
      end

      body.add_system(klass)

      expect { body.run }.to raise_error(Apparatus::Body::MissingDependencyError)
    end

    it "detects circular dependencies" do
      body = described_class.new

      klass1 = Class.new(Apparatus::System) do
        def perform; end
      end

      klass2 = Class.new(Apparatus::System) do
        depends_on klass1
        def perform; end
      end

      klass1.class_eval do
        depends_on klass2
      end

      body.add_systems(klass1, klass2)

      expect { body.run }.to raise_error(Apparatus::Body::CircularDependencyError)
    end

    it "calls before_run and after_run hooks" do
      body = described_class.new
      log = []

      klass = Class.new(Apparatus::System) do
        define_method(:before_run) { log << :before }
        define_method(:perform) { log << :perform }
        define_method(:after_run) { log << :after }
      end

      body.add_system(klass)
      body.run

      expect(log).to eq(%i(before perform after))
    end
  end

  describe "events" do
    it "supports on/emit" do
      body = described_class.new
      events = []
      body.on(:test_event) { |payload| events << payload }

      body.emit(:test_event, foo: :bar)

      expect(events).to contain_exactly(hash_including(foo: :bar))
    end
  end
end
