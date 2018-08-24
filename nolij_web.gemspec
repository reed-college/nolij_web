# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nolij_web/version'

Gem::Specification.new do |spec|
  spec.name          = "nolij_web"
  spec.version       = NolijWeb::Version::VERSION
  spec.authors       = ["Shannon Henderson"]
  spec.email         = ["shenders@reed.edu"]
  spec.description   = %q{A Ruby wrapper for the Nolij Web API}
  spec.summary       = %q{Interact with Nolijweb's REST API}
  spec.homepage      = "https://github.com/reed-college/nolij_web/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files  = spec.files.select { |p| p =~ /^README/ } << 'LICENSE.txt'
  spec.rdoc_options      = %w[--line-numbers --inline-source --main README.rdoc]

  spec.add_runtime_dependency 'rest-client'
  spec.add_runtime_dependency 'nokogiri', '~> 1.6'

  spec.add_development_dependency 'minitest', '~> 5.0.0'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'webmock', '~>1.13'

  spec.required_ruby_version = '>= 1.9.3'
end
