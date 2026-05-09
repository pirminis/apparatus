RSpec.describe Apparatus::System do
  describe "#initialize" do
    it "creates an instance with a body" do
      body = Apparatus::Body.new

      expect { described_class.new(body) }.not_to raise_error
    end

    it "checks argument type" do
      expect { described_class.new(nil) }.to raise_error(TypeError)
      expect { described_class.new("not a body") }.to raise_error(TypeError)
    end
  end

  describe "#entities" do
    it "returns all entities when no filter is set" do
      body = Apparatus::Body.new
      body.create_entity(name: "John")
      body.create_entity(price: 10)

      system = described_class.new(body)

      expect(system.entities.size).to eq(2)
    end

    it "returns filtered entities when filter is set" do
      body = Apparatus::Body.new
      body.create_entity(name: "John", price: 10)
      body.create_entity(name: "Jane")
      body.create_entity(price: 20)

      klass = Class.new(described_class) do
        filter :name, :price
        def perform; end
      end

      system = klass.new(body)

      expect(system.entities.size).to eq(1)
      expect(system.entities.first[:name]).to eq("John")
    end

    it "returns excluded entities when exclude is set" do
      body = Apparatus::Body.new
      body.create_entity(name: "John", price: 10)
      body.create_entity(name: "Jane", price: 20, disabled: true)
      body.create_entity(price: 30)

      klass = Class.new(described_class) do
        filter :name, :price
        exclude :disabled
        def perform; end
      end

      system = klass.new(body)

      expect(system.entities.size).to eq(1)
      expect(system.entities.first[:name]).to eq("John")
    end

    it "returns all entities when no exclude is set" do
      body = Apparatus::Body.new
      body.create_entity(name: "John", disabled: true)
      body.create_entity(name: "Jane")

      klass = Class.new(described_class) do
        def perform; end
      end

      system = klass.new(body)

      expect(system.entities.size).to eq(2)
    end
  end

  describe ".filter" do
    it "stores filter components" do
      klass = Class.new(described_class) do
        filter :name, :age
        def perform; end
      end

      expect(klass.filter_components).to eq(%i(name age))
    end

    it "defaults to empty array" do
      klass = Class.new(described_class) do
        def perform; end
      end

      expect(klass.filter_components).to eq([])
    end
  end

  describe ".exclude" do
    it "stores excluded components" do
      klass = Class.new(described_class) do
        exclude :disabled, :archived
        def perform; end
      end

      expect(klass.exclude_components).to eq(%i(disabled archived))
    end

    it "defaults to empty array" do
      klass = Class.new(described_class) do
        def perform; end
      end

      expect(klass.exclude_components).to eq([])
    end
  end

  describe ".depends_on" do
    it "stores dependencies" do
      dep = Class.new(described_class) { def perform; end }
      klass = Class.new(described_class) do
        depends_on dep
        def perform; end
      end

      expect(klass.dependencies).to eq([dep])
    end

    it "defaults to empty array" do
      klass = Class.new(described_class) { def perform; end }

      expect(klass.dependencies).to eq([])
    end
  end

  describe "#run" do
    it "calls before_run, perform, and after_run in order" do
      klass = Class.new(described_class) do
        def perform
          @log ||= []
          @log << :perform
        end

        def before_run
          @log ||= []
          @log << :before
        end

        def after_run
          @log ||= []
          @log << :after
        end

        attr_reader :log
      end

      system = klass.new(Apparatus::Body.new)
      system.run

      expect(system.log).to eq(%i(before perform after))
    end

    it "raises if perform is not defined" do
      system = described_class.new(Apparatus::Body.new)

      expect { system.run }.to raise_error(NoMethodError, /perform/)
    end
  end
end
