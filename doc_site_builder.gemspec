# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'doc_site_builder/version'

Gem::Specification.new do |spec|
  spec.name          = "doc_site_builder"
  spec.version       = DocSiteBuilder::VERSION
  spec.authors       = ["N. Harrison Ripps"]
  spec.email         = ["nhr@redhat.com"]
  spec.summary       = %q{Builder for multi product documention websites.  This gem has been renamed to ascii_binder and will no longer be supported. Please switch to ascii_binder as soon as possible.}
  spec.description   = %q{Builder for multi product documention websites.  This gem has been renamed to ascii_binder and will no longer be supported. Please switch to ascii_binder as soon as possible.}
  spec.homepage      = "http://github.com/doc_site_builder/doc_site_builder"
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
  spec.add_dependency 'yajl-ruby'
  spec.add_dependency 'tilt'

  spec.post_install_message = <<-MESSAGE
!    The 'doc_site_builder' gem has been deprecated and has been replaced by 'ascii_binder'.
!    See: https://rubygems.org/gems/ascii_binder
!    And: https://github.com/redhataccess/ascii_binder
MESSAGE
end
