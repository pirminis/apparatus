# rubocop:disable RSpec/DescribeClass
RSpec.describe "Apparatus Integration" do
  it "runs the full ECS lifecycle" do
    body = Apparatus::Body.new

    # Prefabs
    product_prefab = body.create_prefab(name: "Product", type: "product", taxable: true)
    shipping_prefab = body.create_prefab(name: "ShippingMethod", type: "shipping_method", enabled: true)

    # Catalog
    iphone = body.instantiate(product_prefab, name: "iPhone 15", price: 999.00)
    macbook = body.instantiate(product_prefab, name: "MacBook Pro", price: 1999.00)
    case_item = body.instantiate(product_prefab, name: "Silicone Case", price: 49.00)

    # Shipping
    express = body.instantiate(shipping_prefab, name: "FedEx Express", price: 4.99, eta: "1-2 days")
    standard = body.instantiate(shipping_prefab, name: "UPS Ground", price: 2.99, eta: "2-3 days")
    free = body.instantiate(shipping_prefab, name: "Free Shipping", price: 0.00, eta: "5-7 days")

    # Named entities
    user = body.create_entity(name: "user_42", type: "user", email: "alice@example.com")
    cart = body.create_entity(name: "cart_abc123", type: "cart")

    # Relationships
    cart.add_relationship(:Contains, iphone)
    cart.add_relationship(:Contains, macbook)
    cart.add_relationship(:Contains, case_item)
    cart.add_relationship(:EligibleFor, express)
    cart.add_relationship(:EligibleFor, standard)
    cart.add_relationship(:EligibleFor, free)

    address = body.create_entity(
      name: "addr_user42_home",
      type: "address",
      country: "US",
      city: "New York",
      zip: "10001",
      street: "123 Broadway"
    )
    user.add_relationship(:DefaultAddress, address)

    # Systems
    calculate_subtotal = Class.new(Apparatus::System) do
      filter :type
      exclude :disabled
      define_method(:perform) do
        target_cart = apparatus.lookup("cart_abc123")
        next unless target_cart

        items = target_cart.relationships(:Contains)
        target_cart[:subtotal] = items.sum { |item| item[:price] }
      end
    end

    apply_tax = Class.new(Apparatus::System) do
      depends_on calculate_subtotal
      define_method(:perform) do
        target_cart = apparatus.lookup("cart_abc123")
        next unless target_cart && target_cart[:subtotal]

        items = target_cart.relationships(:Contains)
        taxable_total = items.select { |i| i[:taxable] }.sum { |i| i[:price] }

        target_cart[:tax] = (taxable_total * 0.21).round(2)
      end
    end

    calculate_shipping = Class.new(Apparatus::System) do
      depends_on calculate_subtotal
      define_method(:perform) do
        target_cart = apparatus.lookup("cart_abc123")
        next unless target_cart

        eligible = target_cart.relationships(:EligibleFor)
        cheapest = eligible.min_by { |m| m[:price] }

        target_cart[:shipping_method] = cheapest
        target_cart[:shipping_cost] = cheapest[:price]
      end
    end

    calculate_total = Class.new(Apparatus::System) do
      depends_on apply_tax
      depends_on calculate_shipping
      define_method(:perform) do
        target_cart = apparatus.lookup("cart_abc123")
        next unless target_cart

        subtotal = target_cart[:subtotal] || 0
        tax = target_cart[:tax] || 0
        shipping = target_cart[:shipping_cost] || 0

        target_cart[:total] = (subtotal + tax + shipping).round(2)
      end
    end

    validate_checkout = Class.new(Apparatus::System) do
      depends_on calculate_total
      define_method(:perform) do
        target_cart = apparatus.lookup("cart_abc123")
        next unless target_cart

        errors = []
        errors << "Cart is empty" if target_cart.relationships(:Contains).empty?
        errors << "No shipping address" unless target_cart.has_relationship?(:ShipTo)
        errors << "Total exceeds limit" if target_cart[:total] && target_cart[:total] > 10_000

        target_cart[:checkout_errors] = errors
        target_cart[:checkout_valid] = errors.empty?
      end
    end

    body.add_systems(
      calculate_subtotal,
      apply_tax,
      calculate_shipping,
      calculate_total,
      validate_checkout
    )

    body.run

    # Assertions before adding address
    expect(cart[:subtotal]).to eq(3047.00)
    expect(cart[:tax]).to eq(639.87)
    expect(cart[:shipping_cost]).to eq(0.00)
    expect(cart[:total]).to eq(3686.87)
    expect(cart[:checkout_valid]).to eq(false)

    # Add shipping address and re-run
    cart.add_relationship(:ShipTo, address)
    body.run

    expect(cart[:checkout_valid]).to eq(true)

    # Remove an item and re-run
    cart.remove_relationship(:Contains, case_item)
    body.run

    expect(cart[:subtotal]).to eq(2998.00)
    expect(cart[:total]).to eq(3627.58)

    # Named lookup
    expect(body.lookup("cart_abc123")).to eq(cart)
    expect(body.lookup("user_42")).to eq(user)

    # Children / hierarchy
    parent = body.create_entity(name: "Parent")
    child = body.create_entity(name: "Child")
    child.child_of(parent)

    expect(body.children_of(parent)).to contain_exactly(child)
    expect(child.parent).to eq(parent)

    # Recursive cleanup
    grandchild = body.create_entity(name: "Grandchild")
    grandchild.child_of(child)

    body.remove_entity(parent)
    expect(body.entities).not_to include(parent, child, grandchild)
  end

  it "demonstrates adding gift wrap without touching existing code" do
    body = Apparatus::Body.new

    product_prefab = body.create_prefab(name: "Product", type: "product", taxable: true)
    iphone = body.instantiate(product_prefab, name: "iPhone 15", price: 999.00)
    macbook = body.instantiate(product_prefab, name: "MacBook Pro", price: 1999.00)
    case_item = body.instantiate(product_prefab, name: "Silicone Case", price: 49.00)

    cart = body.create_entity(name: "cart_gift_test", type: "cart")
    cart.add_relationship(:Contains, iphone)
    cart.add_relationship(:Contains, macbook)
    cart.add_relationship(:Contains, case_item)

    gift_wrap = body.create_entity(name: "GiftWrap", type: "gift_wrap_option", price: 5.00)
    iphone.add_relationship(:CanWrap, gift_wrap)
    macbook.add_relationship(:CanWrap, gift_wrap)

    cart.add_relationship(:Wraps, iphone)

    # Original systems
    calculate_subtotal = Class.new(Apparatus::System) do
      filter :type
      exclude :disabled
      define_method(:perform) do
        target_cart = apparatus.lookup("cart_gift_test")
        next unless target_cart

        items = target_cart.relationships(:Contains)
        target_cart[:subtotal] = items.sum { |item| item[:price] }
      end
    end

    calculate_total = Class.new(Apparatus::System) do
      depends_on calculate_subtotal
      define_method(:perform) do
        target_cart = apparatus.lookup("cart_gift_test")
        next unless target_cart

        target_cart[:total] = (target_cart[:subtotal] || 0) + (target_cart[:gift_wrap_cost] || 0)
      end
    end

    # NEW system added without touching existing ones
    calculate_gift_wrap = Class.new(Apparatus::System) do
      depends_on calculate_subtotal
      define_method(:perform) do
        target_cart = apparatus.lookup("cart_gift_test")
        next unless target_cart

        wrapped_items = target_cart.relationships(:Wraps)
        cost = wrapped_items.sum do |item|
          item.has_relationship?(:CanWrap) ? 5.00 : 0.00
        end

        target_cart[:gift_wrap_cost] = cost
        target_cart[:has_gift_wrap] = cost > 0
      end
    end

    body.add_systems(
      calculate_subtotal,
      calculate_gift_wrap,
      calculate_total
    )

    body.run

    expect(cart[:subtotal]).to eq(3047.00)
    expect(cart[:gift_wrap_cost]).to eq(5.00)
    expect(cart[:total]).to eq(3052.00)
    expect(cart[:has_gift_wrap]).to eq(true)
  end

  it "demonstrates snapshot query behavior" do
    body = Apparatus::Body.new
    entity = body.create_entity(name: "John", age: 100)

    snapshot = body.query(:name, :age)
    entity.remove(:age)

    expect(snapshot.size).to eq(1)
    expect(snapshot.first[:name]).to eq("John")
    expect(body.query(:name, :age)).to be_empty
  end
end
# rubocop:enable RSpec/DescribeClass
