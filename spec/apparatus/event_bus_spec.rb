RSpec.describe Apparatus::EventBus do
  describe "#initialize" do
    it "creates an empty bus" do
      bus = described_class.new

      expect(bus.handlers_for(:anything)).to be_empty
    end
  end

  describe "#on and #emit" do
    it "calls registered handlers" do
      bus = described_class.new
      events = []
      bus.on(:test) { |payload| events << payload }

      bus.emit(:test, foo: :bar)

      expect(events).to contain_exactly(foo: :bar)
    end

    it "calls multiple handlers" do
      bus = described_class.new
      events = []
      bus.on(:test) { |payload| events << [:first, payload] }
      bus.on(:test) { |payload| events << [:second, payload] }

      bus.emit(:test, value: 1)

      expect(events).to eq([[:first, { value: 1 }], [:second, { value: 1 }]])
    end

    it "does nothing for unhandled events" do
      bus = described_class.new

      expect { bus.emit(:unknown) }.not_to raise_error
    end

    it "passes empty hash by default" do
      bus = described_class.new
      payload_received = nil
      bus.on(:test) { |payload| payload_received = payload }

      bus.emit(:test)

      expect(payload_received).to eq({})
    end
  end

  describe "#handlers_for" do
    it "returns a copy of handlers" do
      bus = described_class.new
      bus.on(:test) { nil }

      handlers = bus.handlers_for(:test)
      handlers.clear

      expect(bus.handlers_for(:test).size).to eq(1)
    end
  end

  describe "#clear" do
    it "removes all handlers" do
      bus = described_class.new
      bus.on(:test) { nil }
      bus.clear

      expect(bus.handlers_for(:test)).to be_empty
    end
  end
end
