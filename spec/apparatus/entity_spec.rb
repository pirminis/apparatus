RSpec.describe Apparatus::Entity do
  describe "#initialize" do
    it "creates an instance with empty components by default" do
      entity = described_class.new

      expect(entity.components).to be_a(Hash)
      expect(entity.components).to be_empty
    end

    it "accepts initial components" do
      entity = described_class.new(name: "John", age: 100)

      expect(entity[:name]).to eq("John")
      expect(entity[:age]).to eq(100)
    end

    it "has no id initially" do
      entity = described_class.new

      expect(entity.id).to be_nil
    end

    it "has no body initially" do
      entity = described_class.new

      expect(entity.body).to be_nil
    end

    it "has no name initially" do
      entity = described_class.new

      expect(entity.name).to be_nil
    end

    it "is not a prefab by default" do
      entity = described_class.new

      expect(entity.prefab?).to eq(false)
      expect(entity.prefab_instance?).to eq(false)
    end
  end

  describe "#[]" do
    it "returns component" do
      entity = described_class.new(name: "John")

      expect(entity[:name]).to eq("John")
    end

    it "returns nil for missing component" do
      entity = described_class.new

      expect(entity[:missing]).to be_nil
    end

    it "reads inherited component from prefab" do
      body = Apparatus::Body.new
      prefab = body.create_prefab(defense: 50)
      instance = body.instantiate(prefab)

      expect(instance[:defense]).to eq(50)
    end

    it "reads own component over prefab" do
      body = Apparatus::Body.new
      prefab = body.create_prefab(defense: 50)
      instance = body.instantiate(prefab)
      instance[:defense] = 75

      expect(instance[:defense]).to eq(75)
    end

    it "chains through prefab parents" do
      body = Apparatus::Body.new
      grandparent = body.create_prefab(speed: 100)
      parent = body.create_prefab(defense: 50)
      parent.prefab_parent = grandparent
      instance = body.instantiate(parent)

      expect(instance[:speed]).to eq(100)
    end
  end

  describe "#[]=" do
    it "adds component to an entity" do
      entity = described_class.new(name: "John")

      expect { entity[:age] = 100 }.to change { entity[:age] }.from(nil).to(100)
    end

    it "updates existing component" do
      entity = described_class.new(name: "John")

      expect { entity[:name] = "Jane" }.to change { entity[:name] }.from("John").to("Jane")
    end

    it "notifies body on add when attached" do
      body = Apparatus::Body.new
      entity = body.create_entity(name: "John")

      expect { entity[:age] = 100 }.to change { body.query(:age).size }.from(0).to(1)
    end

    it "emits events when attached to body" do
      body = Apparatus::Body.new
      entity = body.create_entity(name: "John")
      events = []

      body.on(:component_added) { |payload| events << payload }
      entity[:age] = 100

      expect(events).to contain_exactly(
        hash_including(entity: entity, component: :age)
      )
    end

    it "emits update events for existing components" do
      body = Apparatus::Body.new
      entity = body.create_entity(name: "John")
      events = []

      body.on(:component_updated) { |payload| events << payload }
      entity[:name] = "Jane"

      expect(events).to contain_exactly(
        hash_including(entity: entity, component: :name)
      )
    end
  end

  describe "#add" do
    it "is an alias for []=" do
      entity = described_class.new

      entity.add(:name, "John")

      expect(entity[:name]).to eq("John")
    end
  end

  describe "#remove" do
    it "removes a component" do
      entity = described_class.new(name: "John", age: 100)

      entity.remove(:age)

      expect(entity[:age]).to be_nil
      expect(entity[:name]).to eq("John")
    end

    it "returns the removed value" do
      entity = described_class.new(name: "John")

      expect(entity.remove(:name)).to eq("John")
    end

    it "notifies body when attached" do
      body = Apparatus::Body.new
      entity = body.create_entity(name: "John", age: 100)

      expect { entity.remove(:age) }.to change { body.query(:age).size }.from(1).to(0)
    end

    it "emits component_removed event" do
      body = Apparatus::Body.new
      entity = body.create_entity(name: "John")
      events = []

      body.on(:component_removed) { |payload| events << payload }
      entity.remove(:name)

      expect(events).to contain_exactly(
        hash_including(entity: entity, component: :name)
      )
    end
  end

  describe "#has?" do
    it "returns true when all components exist" do
      entity = described_class.new(name: "John", age: 100, color: "red")

      expect(entity.has?(:name, :age)).to eq(true)
    end

    it "returns false when any component is missing" do
      entity = described_class.new(name: "John", age: 100, color: "red")

      expect(entity.has?(:name, :job)).to eq(false)
    end

    it "returns true for a single existing component" do
      entity = described_class.new(name: "John")

      expect(entity.has?(:name)).to eq(true)
    end

    it "returns true for empty check" do
      entity = described_class.new(name: "John")

      expect(entity.has?).to eq(true)
    end
  end

  describe "#owns?" do
    it "returns true for own component" do
      body = Apparatus::Body.new
      prefab = body.create_prefab(defense: 50)
      instance = body.instantiate(prefab)
      instance[:defense] = 75

      expect(instance.owns?(:defense)).to eq(true)
    end

    it "returns false for inherited component" do
      body = Apparatus::Body.new
      prefab = body.create_prefab(defense: 50)
      instance = body.instantiate(prefab)

      expect(instance.owns?(:defense)).to eq(false)
    end
  end

  describe "#prefab? and #prefab_instance?" do
    it "identifies prefab entities" do
      body = Apparatus::Body.new
      prefab = body.create_prefab(name: "Spaceship")

      expect(prefab.prefab?).to eq(true)
      expect(prefab.prefab_instance?).to eq(false)
    end

    it "identifies prefab instances" do
      body = Apparatus::Body.new
      prefab = body.create_prefab(defense: 50)
      instance = body.instantiate(prefab)

      expect(instance.prefab?).to eq(false)
      expect(instance.prefab_instance?).to eq(true)
    end
  end

  describe "relationships" do
    describe "#add_relationship" do
      it "adds a relationship to a target" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        bob = body.create_entity(name: "Bob")

        bob.add_relationship(:Likes, alice)

        expect(bob.has_relationship?(:Likes, alice)).to eq(true)
      end

      it "raises for non-entity target" do
        body = Apparatus::Body.new
        bob = body.create_entity(name: "Bob")

        expect { bob.add_relationship(:Likes, "not an entity") }.to raise_error(ArgumentError)
      end

      it "emits relationship_added event" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        bob = body.create_entity(name: "Bob")
        events = []

        body.on(:relationship_added) { |payload| events << payload }
        bob.add_relationship(:Likes, alice)

        expect(events).to contain_exactly(
          hash_including(entity: bob, relationship: :Likes, target: alice)
        )
      end
    end

    describe "#remove_relationship" do
      it "removes a specific relationship" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        bob = body.create_entity(name: "Bob")
        bob.add_relationship(:Likes, alice)

        bob.remove_relationship(:Likes, alice)

        expect(bob.has_relationship?(:Likes, alice)).to eq(false)
      end

      it "removes all relationships of a type" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        charlie = body.create_entity(name: "Charlie")
        bob = body.create_entity(name: "Bob")
        bob.add_relationship(:Likes, alice)
        bob.add_relationship(:Likes, charlie)

        bob.remove_relationship(:Likes)

        expect(bob.has_relationship?(:Likes)).to eq(false)
      end

      it "emits relationship_removed event" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        bob = body.create_entity(name: "Bob")
        bob.add_relationship(:Likes, alice)
        events = []

        body.on(:relationship_removed) { |payload| events << payload }
        bob.remove_relationship(:Likes, alice)

        expect(events).to contain_exactly(
          hash_including(entity: bob, relationship: :Likes, target: alice)
        )
      end
    end

    describe "#has_relationship?" do
      it "checks exact relationship" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        bob = body.create_entity(name: "Bob")
        bob.add_relationship(:Likes, alice)

        expect(bob.has_relationship?(:Likes, alice)).to eq(true)
        expect(bob.has_relationship?(:Likes, body.create_entity)).to eq(false)
      end

      it "checks any relationship of type" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        bob = body.create_entity(name: "Bob")

        expect(bob.has_relationship?(:Likes)).to eq(false)
        bob.add_relationship(:Likes, alice)
        expect(bob.has_relationship?(:Likes)).to eq(true)
      end
    end

    describe "#relationships" do
      it "returns targets for a type" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        charlie = body.create_entity(name: "Charlie")
        bob = body.create_entity(name: "Bob")
        bob.add_relationship(:Likes, alice)
        bob.add_relationship(:Likes, charlie)

        expect(bob.relationships(:Likes)).to contain_exactly(alice, charlie)
      end

      it "returns all relationships" do
        body = Apparatus::Body.new
        alice = body.create_entity(name: "Alice")
        pizza = body.create_entity(name: "Pizza")
        bob = body.create_entity(name: "Bob")
        bob.add_relationship(:Likes, alice)
        bob.add_relationship(:Eats, pizza)

        result = bob.relationships
        expect(result[:Likes]).to contain_exactly(alice)
        expect(result[:Eats]).to contain_exactly(pizza)
      end
    end
  end

  describe "hierarchies" do
    describe "#child_of" do
      it "adds ChildOf relationship" do
        body = Apparatus::Body.new
        parent = body.create_entity(name: "Parent")
        child = body.create_entity(name: "Child")

        child.child_of(parent)

        expect(child.parent).to eq(parent)
        expect(child.has_relationship?(:ChildOf, parent)).to eq(true)
      end
    end

    describe "#parent" do
      it "returns nil without parent" do
        entity = described_class.new

        expect(entity.parent).to be_nil
      end

      it "returns the parent entity" do
        body = Apparatus::Body.new
        parent = body.create_entity(name: "Parent")
        child = body.create_entity(name: "Child")
        child.child_of(parent)

        expect(child.parent).to eq(parent)
      end
    end
  end
end
