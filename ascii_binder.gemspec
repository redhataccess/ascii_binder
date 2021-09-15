# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ascii_binder/version'

Gem::Specification.new do |spec|
  spec.name          = "ascii_binder"
  spec.version       = AsciiBinder::VERSION
  spec.authors       = ["N. Harrison Ripps", "Jason Frey", "Carlos Munoz", "Brian Exelbierd", "Vikram Goyal"]
  spec.email         = ["nhr@redhat.com", "jfrey@redhat.com", "chavo16@hotmail.com", "bex@pobox.com", "vigoyal@redhat.com"]
  spec.summary       = %q{AsciiBinder is an AsciiDoc-based system for authoring and publishing closely related documentation sets from a single source.}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/redhataccess/ascii_binder"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "cucumber", "~> 2.3.3"
  spec.add_development_dependency "diff_dirs", "~> 0.1.2"
  spec.add_dependency "rake", "~> 12.3.3"

  spec.add_dependency 'asciidoctor', '~> 2.0.10'
  spec.add_dependency 'asciidoctor-diagram', '~> 2.0.2'
  spec.add_dependency 'rouge', '~> 3.18.0'
  spec.add_dependency 'git'
  spec.add_dependency 'guard'
  spec.add_dependency 'guard-shell'
  spec.add_dependency 'guard-livereload'
  spec.add_dependency 'haml'
  spec.add_dependency 'json'
  spec.add_dependency 'sitemap_generator', '~> 6.0.1'
  spec.add_dependency 'trollop', '~> 2.1.2'
  spec.add_dependency 'yajl-ruby', '~> 1.3.0'
  spec.add_dependency 'tilt'
  spec.add_dependency 'bigdecimal'

end
