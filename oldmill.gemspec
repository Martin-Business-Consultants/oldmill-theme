# frozen_string_literal: true

require_relative "lib/oldmill/version"

Gem::Specification.new do |spec|
  spec.name = "oldmill"
  spec.version = Oldmill::VERSION
  spec.summary = "The Old Mill Brewpub & Grill website, as a CMS theme"
  spec.authors = ["Martin Business Consultants"]
  spec.files = Dir["{app,config,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
