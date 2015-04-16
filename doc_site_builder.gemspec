# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'doc_site_builder/version'

Gem::Specification.new do |spec|
  spec.name          = "doc_site_builder"
  spec.version       = DocSiteBuilder::VERSION
  spec.authors       = ["N. Harrison Ripps"]
  spec.email         = ["nhr@redhat.com"]
  spec.summary       = %q{Builder for multi product documention websites.}
  spec.description   = %q{Builder for multi product documention websites.}
  spec.homepage      = "http://github.com/doc_site_builder/doc_site_builder"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
