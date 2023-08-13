# What is apparatus?

Have you ever worked on code that evolves so quickly that not only it gives you anxiety, but it becomes technical debt over time?

Apparatus is a very simple architectural way to solve this. It uses composition over inheritance and is a (very) simplified ECS (entity-component-system) implementation.

## What does it do?

It ensures your complex parts code are highly structured and easy to understand and modify:
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

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pirminis/apparatus.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
