# frozen_string_literal: true

require_relative "lib/easy_params/version"

Gem::Specification.new do |spec|
  spec.name          = "easy_params_enhanced"
  spec.version       = EasyParams::VERSION
  spec.authors       = ["Weicheng Zhu"]
  spec.email         = ["weicheng.zhu@icloud.com"]

  spec.summary       = "A simple and extensible parameter validation library for Rails."
  spec.description   = "EasyParams is a lightweight library for Rails applications that provides a DSL for defining and validating parameters, including support for nested attributes and custom validations."
  spec.homepage      = "https://github.com/your_username/easy_params"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/your_username/easy_params"
  spec.metadata["changelog_uri"]     = "https://github.com/your_username/easy_params/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added to git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Add runtime dependencies (libraries your gem depends on)
  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "activemodel", ">= 6.0"

  # Add development dependencies (libraries needed for development and testing)
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "bundler", "~> 2.0"

  # Additional information
  spec.post_install_message = <<~MESSAGE
    Thank you for installing EasyParams! 🎉
    Documentation and usage examples can be found at:
    #{spec.homepage}
  MESSAGE
end
