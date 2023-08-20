class TestSystem1 < Apparatus::System
  def run; end
end

class TestSystem2 < Apparatus::System
  def run; end
end

class NoRunSystem < Apparatus::System; end

class NotApparatusSystem
  def run; end
end

RSpec.describe Apparatus::Body do
  describe "#initialize" do
    it "creates an instance" do
      apparatus = Apparatus::Body.new

      expect(apparatus.entities).to be_a(Array)
      expect(apparatus.systems).to be_a(Array)
    end
  end

  describe "#add_system" do
    it "adds a system" do
      apparatus = described_class.new

      expect { apparatus.add_system(TestSystem1) }.to change { apparatus.systems.size }.from(0).to(1)
    end

    it "raises error if system has no #run method" do
      apparatus = described_class.new

      expect { apparatus.add_system(NoRunSystem) }.to raise_error(NoMethodError)
    end

    it "raises error if 'Apparatus::System' is not included in the class hierarchy" do
      apparatus = described_class.new

      expect { apparatus.add_system(NotApparatusSystem) }.to raise_error(Apparatus::Body::SystemHierarchyError)
    end
  end

  describe "#add_systems" do
    it "adds multiple systems" do
      apparatus = described_class.new

      expect { apparatus.add_systems(TestSystem1, TestSystem2) }.to change { apparatus.systems.size }.from(0).to(2)
    end
  end

  describe "#add_entity" do
    it "adds an entity" do
      components = {
        name: "John",
        age: 100
      }

      person = Apparatus::Entity.new(components)

      apparatus = described_class.new

      expect { apparatus.add_entity(person) }.to change { apparatus.entities.size }.from(0).to(1)
    end
  end

  describe "#add_entities" do
    it "adds an entities" do
      components = {
        name: "John",
        age: 100
      }

      person = Apparatus::Entity.new(components)

      components = {
        name: "Table",
        color: "brown"
      }

      table = Apparatus::Entity.new(components)

      apparatus = described_class.new

      expect { apparatus.add_entities(person, table) }.to change { apparatus.entities.size }.from(0).to(2)
    end
  end

  class DoubleThePrice < Apparatus::System
    def run
      entities.each do |entity|
        next unless entity.has?(:price)

        entity[:price] *= 2.0
      end
    end
  end

  class ShowItems < Apparatus::System
    def run
      puts "Items:"

      entities.each do |entity|
        next unless entity.has?(:name, :price)

        puts "  #{entity[:name]} ($#{entity[:price]})"
      end
    end
  end

  describe "#run" do
    it "runs systems" do
      green_apple = Apparatus::Entity.new({
        name: "Apple",
        color: "green"
      })

      brown_table = Apparatus::Entity.new({
        name: "Table",
        color: "brown",
        price: 15.0
      })

      apparatus = described_class.new
      apparatus.add_entities(green_apple, brown_table)
      apparatus.add_systems(DoubleThePrice, ShowItems)

      expect { apparatus.run }.to output(<<~OUTPUT).to_stdout
        Items:
          Table ($30.0)
      OUTPUT
    end
  end
end
