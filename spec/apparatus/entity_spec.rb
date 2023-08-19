RSpec.describe Apparatus::Entity do
  describe "#initialize" do
    it "creates an instance" do
      entity = described_class.new

      expect(entity.components).to be_a(Hash)
      expect(entity.components).to be_empty
    end
  end

  describe "#[]" do
    it "returns component" do
      components = {
        name: "John"
      }

      entity = described_class.new(components)

      expect(entity[:name]).to eq("John")
    end
  end

  describe "#[]=" do
    it "adds component to an entity" do
      components = {
        name: "John"
      }

      entity = described_class.new(components)

      expect { entity[:age] = 100 }.to change { entity[:age] }.from(nil).to(100)
    end
  end

  describe "#has?" do
    it "returns true" do
      components = {
        name: "John",
        age: 100,
        color: "red"
      }

      entity = described_class.new(components)

      expect(entity.has?(:name, :age)).to eq(true)
    end

    it "returns false" do
      components = {
        name: "John",
        age: 100,
        color: "red"
      }

      entity = described_class.new(components)

      expect(entity.has?(:name, :job)).to eq(false)
    end
  end
end
