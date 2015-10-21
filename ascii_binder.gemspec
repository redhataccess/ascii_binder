# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ascii_binder/version'

Gem::Specification.new do |spec|
  spec.name          = "ascii_binder"
  spec.version       = AsciiBinder::VERSION
  spec.authors       = ["N. Harrison Ripps","Jason Frey"]
  spec.email         = ["nhr@redhat.com","jfrey@redhat.com"]
  spec.summary       = %q{Builder for multi product documention websites.}
  spec.description   = %q{Builder for multi product documention websites.}
  spec.homepage      = "http://asciibinder.org/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_dependency "rake", "~> 10.0"

  spec.add_dependency 'asciidoctor'
  spec.add_dependency 'asciidoctor-diagram'
  spec.add_dependency 'git'
  spec.add_dependency 'guard'
  spec.add_dependency 'guard-shell'
  spec.add_dependency 'guard-livereload'
  spec.add_dependency 'haml'
  spec.add_dependency 'json'
  spec.add_dependency 'pandoc-ruby'
  spec.add_dependency 'sitemap_generator', '~> 5.1.0'
  spec.add_dependency 'trollop', '~> 2.1.2'
  spec.add_dependency 'yajl-ruby'
  spec.add_dependency 'tilt'
end
