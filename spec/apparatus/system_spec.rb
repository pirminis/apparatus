RSpec.describe Apparatus::System do
  describe "#initialize" do
    it "creates and instance of a class" do
      apparatus = Apparatus::Body.new
      entities = []

      system = described_class.new(apparatus, entities)

      expect(system).to be_a(described_class)
    end

    it "checks argument types" do
      apparatus = Apparatus::Body.new
      entities = []

      both_args_wrong = -> { described_class.new(nil, nil) }
      second_arg_wrong = -> { described_class.new(apparatus, nil) }
      first_arg_wrong = -> { described_class.new(nil, entities) }
      correct_use = -> { described_class.new(apparatus, entities) }

      expect { both_args_wrong.call }.to raise_error(TypeError)
      expect { second_arg_wrong.call }.to raise_error(TypeError)
      expect { first_arg_wrong.call }.to raise_error(TypeError)
      expect { correct_use.call }.not_to raise_error
    end
  end
end
