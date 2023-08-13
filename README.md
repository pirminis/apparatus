# What is apparatus?

Have you ever worked on code that evolves so quickly that not only it gives you anxiety, but becomes technical debt over time?

Apparatus is a very simple architectural way to solve this. It uses composition over inheritance and is a (very) simple ECS (entity-component-system) implementation.

It decouples data and logic.

## What does it do?

It ensures your complex code parts are highly structured and easy to understand and modify:
- code is organized and tidy by default
- data is always separated from logic
- adding, removing, modifying data and logic is easy
- complete freedom how data is shaped
- very easy to to see what is being done at a glance

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

Let's build code that outputs delivery methods to the standard output. We have a imaginary cart and three shipping methods.

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

# entities
delivery = Entity.new({
  type: Type.new("delivery_method"),
  identifier: Identifier.new("delivery"),
  name: Name.new("Delivery by courier"),
  price: Price.new(3.99)
})
pickup = Entity.new({
  type: Type.new("delivery_method"),
  identifier: Identifier.new("pickup"),
  name: Name.new("Pickup in closest store"),
  price: Price.new(0.0)
})
pigeon = Entity.new({
  type: Type.new("delivery_method"),
  identifier: Identifier.new("pigeon"),
  name: Name.new("Delivery by pigeon"),
  price: Price.new(50.0)
})
cart = Entity.new({
  type: Type.new("cart"),
  total_price: Price.new(27.0),
  total_weight: WeightInKg.new(5.0)
})

# systems
class PrintShippingMethods < System
  def run
    entities.each do |entity|
      next if !entity.has?(:type, :price)

      next if entity[:type].value.to_s != "delivery_method"

      name, price, enabled = entity[:name], entity[:price], entity[:enabled]

      next if enabled && !enabled.value

      puts "#{name.value} (#{price.value} €)"
    end
  end
end

class EnableDeliveryMethods < System
  def run
    cart = entities.find { _1.has?(:type) && _1[:type].value.to_s == "cart" }

    return if !cart

    delivery_methods = entities.select do |entity|
      entity.has?(:type, :identifier) &&
        entity[:type].value.to_s == "delivery_method"
    end

    delivery_methods.each do |delivery_method|
      delivery_method[:enabled] = delivery_method[:identifier].value.to_s == "pigeon" ?
                                    Boolean.new(cart[:total_weight].value < 0.1) :
                                    Boolean.new(true)
    end
  end
end

# apparatus itself
apparatus = Apparatus::Body.new

apparatus.add_entities(delivery, pickup, pigeon, cart)
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

## What apparatus is not

This is not THE SOLUTION.

This gem is not meant to be used always, everywhere. It shines when you have suspicion that the incoming feature will be extremely volatile (business logic will change a lot or complexity will grow, there might be a lot of feature requests, etc).

## Drawbacks in the implementation

If you check the source code of this gem, it is absurdly simple. However, with simplicity come the drawbacks:
- No magic
- No queries or cached queries
- Almost no helper methods
- If you have not encountered ECS, then apparatus might seem strange

## Alternatives

There are alternatives that have a lot more features:
- https://github.com/guitsaru/draco
- https://github.com/ged/chione
- https://github.com/jtuttle/baku

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pirminis/apparatus.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
