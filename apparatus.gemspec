# frozen_string_literal: true

require_relative "lib/apparatus/version"

Gem::Specification.new do |spec|
  spec.name = "apparatus"
  spec.version = Apparatus::VERSION
  spec.authors = ["pirminis"]
  spec.email = ["pirminis@gmail.com"]

  spec.summary = "Take control of your business logic."
  spec.description = "Systematic approach to controlling complex business logic by using entity-component-system architectural pattern."
  spec.homepage = "https://github.com/pirminis/apparatus"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/pirminis/apparatus/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w(bin/ test/ spec/ features/ .git .circleci appveyor))
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
