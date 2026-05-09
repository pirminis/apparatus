# What is apparatus?

Have you ever worked on code that evolves so quickly that not only it gives you anxiety, but becomes technical debt over time?

Apparatus is a simple architectural way to solve this. It uses composition over inheritance and is an ECS (entity-component-system) implementation.

It decouples logic from data.

## What does it do?

It ensures your complex code parts are highly structured and easy to understand and modify:
- code is organized and tidy by default
- data is always separated from logic
- adding, removing, modifying data and logic is easy
- complete freedom how data is shaped
- very easy to see what is being done at a glance

## When to use it?

Only use this gem for the business logic that is very volatile:
- there are or will be a lot of changes in the business logic
- feature requests come frequently and are aplenty
- you still have no idea how to structure your complex piece of code

## Installation

### Using Rubygems:

```sh
gem install apparatus
```

### Using Bundler:

Add the following to your Gemfile:

```sh
gem "apparatus"
```

## Usage

### Basic example

Let's build code that outputs delivery methods to the standard output. We have an imaginary cart and three shipping methods.

```ruby
require "apparatus"

# aliases (optional)
Entity = Apparatus::Entity
System = Apparatus::System

# component classes
Type = Struct.new(:value)
Name = Struct.new(:value)
Identifier = Struct.new(:value)
Price = Struct.new(:value)
WeightInKg = Struct.new(:value)
Boolean = Struct.new(:value)

# define prefabs (optional, but convenient)
apparatus = Apparatus::Body.new

delivery_method_prefab = apparatus.create_prefab(
  type: Type.new("delivery_method")
)
cart_prefab = apparatus.create_prefab(
  type: Type.new("cart")
)

# create instances from prefabs
delivery = apparatus.instantiate(delivery_method_prefab,
  identifier: Identifier.new("delivery"),
  name: Name.new("Delivery by courier"),
  price: Price.new(3.99)
)
pickup = apparatus.instantiate(delivery_method_prefab,
  identifier: Identifier.new("pickup"),
  name: Name.new("Pickup in closest store"),
  price: Price.new(0.0)
)
pigeon = apparatus.instantiate(delivery_method_prefab,
  identifier: Identifier.new("pigeon"),
  name: Name.new("Delivery by pigeon"),
  price: Price.new(50.0)
)
cart = apparatus.instantiate(cart_prefab,
  total_price: Price.new(27.0),
  total_weight: WeightInKg.new(5.0)
)

# systems
class EnableDeliveryMethods < System
  def perform
    cart = apparatus.with(:total_price).first

    return unless cart

    delivery_methods = apparatus.with(:identifier, :price)

    delivery_methods.each do |delivery_method|
      delivery_method[:enabled] = delivery_method[:identifier].value.to_s == "pigeon" ?
                                    Boolean.new(cart[:total_weight].value < 0.1) :
                                    Boolean.new(true)
    end
  end
end

class PrintShippingMethods < System
  filter :type, :price
  exclude :disabled
  depends_on EnableDeliveryMethods

  def perform
    entities.each do |entity|
      next if entity[:type].value.to_s != "delivery_method"

      name, price, enabled = entity[:name], entity[:price], entity[:enabled]

      next if enabled && !enabled.value

      puts "#{name.value} (#{price.value} €)"
    end
  end
end

apparatus.add_systems(
  EnableDeliveryMethods,
  PrintShippingMethods
)

# run all systems
apparatus.run
```

If you run this code, the output is following:
```
Delivery by courier (3.99)
Pickup in closest store (0.0)
```

Delivery by pigeon is missing, because the cart weight is too heavy and pigeon cannot bring you (imaginary) package.

However if you comment the line `EnableDeliveryMethods,` and run the code again, the output changes to:
```
Delivery by courier (3.99)
Pickup in closest store (0.0)
Delivery by pigeon (50.0)
```

## Noteworthy things about the basic example

I think you should notice some positive things about the basic example:
- Component classes are really simple classes that can be of any shape that is useful to you. I chose `Struct`, but it can be anything: custom class, String, Integer, etc.
- An entity is just a collection of components
- A system just processes entities one by one
- When apparatus is run, each system is run one by one
- Nowhere did I call a loose method on a data object: data is data and has no logic; all logic lies within systems
- I can easily disable any amount of systems if needed without breaking the apparatus
- The whole implementation is very linear and easy to read
- Code is easy to debug (just use `puts` or `byebug`)

## Queries and filtering

Instead of manually scanning all entities, you can query by component:

```ruby
# All entities with :name and :price
apparatus.query(:name, :price)

# All entities with :type (alias for query)
apparatus.with(:type)
```

Systems can declare a filter so they only receive matching entities:

```ruby
class PriceTagPrinter < System
  filter :name, :price

  def perform
    entities.each do |entity|
      puts "#{entity[:name]} costs #{entity[:price]}"
    end
  end
end
```

You can also exclude entities that have certain components:

```ruby
class ActiveProducts < System
  filter :name, :price
  exclude :disabled, :archived

  def perform
    entities.each do |entity|
      puts "#{entity[:name]} is active"
    end
  end
end
```

## Relationships

Entities can have relationships to other entities. This turns your ECS into a graph:

```ruby
bob = apparatus.create_entity(name: "Bob")
alice = apparatus.create_entity(name: "Alice")
pizza = apparatus.create_entity(name: "Pizza")

bob.add_relationship(:Likes, alice)
bob.add_relationship(:Eats, pizza)

bob.has_relationship?(:Likes, alice)  # => true
bob.relationships(:Likes)             # => [alice]

# Query relationships
apparatus.query_relationship(:Likes, alice)   # everyone who likes Alice
apparatus.query_relationship(:Likes, :*)      # everyone who likes anything
```

## Hierarchies

Built on relationships:

```ruby
spaceship = apparatus.create_entity(name: "Spaceship")
cockpit = apparatus.create_entity(name: "Cockpit")

cockpit.child_of(spaceship)          # adds (ChildOf, spaceship) relationship
apparatus.children_of(spaceship)     # => [cockpit]
cockpit.parent                       # => spaceship

# Removing a parent recursively removes all children
apparatus.remove_entity(spaceship)   # cockpit is deleted too
```

## Prefabs

Prefabs are template entities. Instances inherit components:

```ruby
spaceship = apparatus.create_prefab(name: "Spaceship", defense: 50, health: 100)

# Create instance
frigate = apparatus.instantiate(spaceship)
frigate[:defense]   # => 50 (inherited)
frigate.owns?(:defense)  # => false

# Override
frigate[:defense] = 75
frigate.owns?(:defense)  # => true

# Prefab variant (prefab inheriting from prefab)
freighter = apparatus.create_prefab(health: 150)
freighter.prefab_parent = spaceship
heavy = apparatus.instantiate(freighter)
heavy[:defense]  # => 50 (from Spaceship)
heavy[:health]   # => 150 (from Freighter)
```

## Named entities

Entities can have names for easy lookup:

```ruby
user = apparatus.create_entity(name: "user_42", email: "alice@example.com")
apparatus.lookup("user_42")  # => user entity
```

## System ordering

Systems run in the order they are registered. If you register A, then B, then X, they run as A → B → X.

You can declare dependencies to ensure a system is only valid when another is present:

```ruby
class CalculateTotal < System
  def perform; end
end

class PrintReceipt < System
  depends_on CalculateTotal
  def perform; end
end
```

## Events

Apparatus emits events automatically and supports custom events:

```ruby
apparatus.on(:entity_added) { |payload| puts "Added entity #{payload[:entity].id}" }
apparatus.on(:component_updated) { |payload| puts "Updated #{payload[:component]}" }
apparatus.on(:relationship_added) { |payload| puts "#{payload[:entity].name} #{payload[:relationship]} #{payload[:target].name}" }
apparatus.emit(:order_placed, order_id: 123)
```

Built-in events: `:entity_added`, `:entity_removed`, `:component_added`, `:component_updated`, `:component_removed`, `:relationship_added`, `:relationship_removed`.

## Ecommerce Example: Cart & Checkout

This example shows a shopping cart system built with Apparatus — demonstrating **prefabs**, **relationships**, **named entities**, and **systems**. Then it shows how to add an unexpected feature (gift wrapping) without touching existing code.

### Setup: Prefabs and Catalog

```ruby
body = Apparatus::Body.new

# --- Prefabs: reusable templates ---
product_prefab = body.create_prefab(name: "Product", type: "product", taxable: true)
shipping_prefab = body.create_prefab(name: "ShippingMethod", type: "shipping_method", enabled: true)

# --- Catalog items from prefabs ---
iphone = body.instantiate(product_prefab, name: "iPhone 15", price: 999.00)
macbook = body.instantiate(product_prefab, name: "MacBook Pro", price: 1999.00)
case_item = body.instantiate(product_prefab, name: "Silicone Case", price: 49.00)

# --- Shipping methods ---
express = body.instantiate(shipping_prefab, name: "FedEx Express", price: 4.99, eta: "1-2 days")
standard = body.instantiate(shipping_prefab, name: "UPS Ground", price: 2.99, eta: "2-3 days")
free = body.instantiate(shipping_prefab, name: "Free Shipping", price: 0.00, eta: "5-7 days")

# --- Named entities for easy lookup ---
user = body.create_entity(name: "user_42", type: "user", email: "alice@example.com")
cart = body.create_entity(name: "cart_abc123", type: "cart")

# --- Relationships connect entities ---
cart.add_relationship(:Contains, iphone)
cart.add_relationship(:Contains, macbook)
cart.add_relationship(:Contains, case_item)
cart.add_relationship(:EligibleFor, express)
cart.add_relationship(:EligibleFor, standard)
cart.add_relationship(:EligibleFor, free)

# User's default shipping address
address = body.create_entity(
  name: "addr_user42_home",
  type: "address",
  country: "US",
  city: "New York",
  zip: "10001",
  street: "123 Broadway"
)
user.add_relationship(:DefaultAddress, address)
```

### Systems: The Business Logic

```ruby
class CalculateSubtotal < Apparatus::System
  filter :type
  exclude :disabled

  def perform
    return unless apparatus.lookup("cart_abc123")

    cart = apparatus.lookup("cart_abc123")
    items = cart.relationships(:Contains)

    cart[:subtotal] = items.sum { |item| item[:price] }
  end
end

class ApplyTax < Apparatus::System
  depends_on CalculateSubtotal

  def perform
    cart = apparatus.lookup("cart_abc123")
    return unless cart && cart[:subtotal]

    items = cart.relationships(:Contains)
    taxable_total = items.select { |i| i[:taxable] }.sum { |i| i[:price] }

    cart[:tax] = (taxable_total * 0.21).round(2)
    cart[:tax_rate] = 0.21
  end
end

class CalculateShipping < Apparatus::System
  depends_on CalculateSubtotal

  def perform
    cart = apparatus.lookup("cart_abc123")
    return unless cart

    eligible = cart.relationships(:EligibleFor)
    cheapest = eligible.min_by { |m| m[:price] }

    cart[:shipping_method] = cheapest
    cart[:shipping_cost] = cheapest[:price]
  end
end

class CalculateTotal < Apparatus::System
  depends_on ApplyTax
  depends_on CalculateShipping

  def perform
    cart = apparatus.lookup("cart_abc123")
    return unless cart

    subtotal = cart[:subtotal] || 0
    tax = cart[:tax] || 0
    shipping = cart[:shipping_cost] || 0

    cart[:total] = (subtotal + tax + shipping).round(2)
  end
end

class ValidateCheckout < Apparatus::System
  depends_on CalculateTotal

  def perform
    cart = apparatus.lookup("cart_abc123")
    return unless cart

    errors = []
    errors << "Cart is empty" if cart.relationships(:Contains).empty?
    errors << "No shipping address" unless cart.has_relationship?(:ShipTo)
    errors << "Total exceeds limit" if cart[:total] && cart[:total] > 10_000

    cart[:checkout_errors] = errors
    cart[:checkout_valid] = errors.empty?
  end
end
```

### Running the Checkout

```ruby
body.add_systems(
  CalculateSubtotal,
  ApplyTax,
  CalculateShipping,
  CalculateTotal,
  ValidateCheckout
)

body.run

cart = body.lookup("cart_abc123")
puts "Subtotal: $#{cart[:subtotal]}"       # => 3047.00
puts "Tax (21%): $#{cart[:tax]}"           # => 640.08
puts "Shipping: $#{cart[:shipping_cost]}"  # => 0.00 (Free selected)
puts "Total: $#{cart[:total]}"             # => 3687.08
puts "Valid? #{cart[:checkout_valid]}"     # => false (no ShipTo address)

# Fix: add shipping address relationship
cart.add_relationship(:ShipTo, body.lookup("addr_user42_home"))

# Re-run — systems recalculate fresh
body.run
puts "Valid? #{cart[:checkout_valid]}"     # => true
```

### Adding an Unexpected Feature: Gift Wrapping

Your PM walks in: *"We need gift wrapping. Some products can be wrapped for $5 each. The customer should be able to opt in per item. If any item is wrapped, show a 'Gift Message' field in checkout."*

**Don't touch any existing system.** Just add new entities, relationships, and one new system.

```ruby
# 1. Mark wrap-eligible products
gift_wrap = body.create_entity(name: "GiftWrap", type: "gift_wrap_option", price: 5.00)

iphone.add_relationship(:CanWrap, gift_wrap)
macbook.add_relationship(:CanWrap, gift_wrap)
# case_item cannot be wrapped

# 2. Customer opts in per item
cart.add_relationship(:Wraps, iphone)

# 3. One new system
class CalculateGiftWrap < Apparatus::System
  depends_on CalculateSubtotal

  def perform
    cart = apparatus.lookup("cart_abc123")
    return unless cart

    wrapped_items = cart.relationships(:Wraps)
    gift_wrap_cost = wrapped_items.sum do |item|
      item.has_relationship?(:CanWrap) ? 5.00 : 0.00
    end

    cart[:gift_wrap_cost] = gift_wrap_cost
    cart[:has_gift_wrap] = gift_wrap_cost > 0
  end
end

# 4. Register and run
body.add_systems(
  CalculateSubtotal,
  ApplyTax,
  CalculateShipping,
  CalculateGiftWrap,   # ← NEW
  CalculateTotal,
  ValidateCheckout
)

body.run

puts "Gift wrap: $#{cart[:gift_wrap_cost]}"  # => 5.00
puts "Total: $#{cart[:total]}"               # => 3692.08
puts "Has gift wrap? #{cart[:has_gift_wrap]}" # => true
```

### Why this works so well

| Challenge | How Apparatus handles it |
|-----------|-------------------------|
| **New data per item** | `CanWrap` relationship on products — no schema changes |
| **Customer choice per item** | `Wraps` relationship on cart — no cart schema changes |
| **Conditional UI field** | `has_gift_wrap` component emitted by system — frontend just checks it |
| **Cost calculation** | New system reads relationships, writes component — isolated logic |
| **No existing code touched** | Old systems don't know about gift wrap; new system doesn't break them |

## What apparatus is not

This is not THE SOLUTION.

This gem is not meant to be used always, everywhere. It shines when you have suspicion that the incoming feature will be extremely volatile (business logic will change a lot or complexity will grow, there might be a lot of feature requests, etc).

## Alternatives

There are alternatives that have a lot more features:
- https://github.com/guitsaru/draco
- https://github.com/ged/chione
- https://github.com/jtuttle/baku

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `make check` to run the checks (rubocop + tests). You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pirminis/apparatus.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
