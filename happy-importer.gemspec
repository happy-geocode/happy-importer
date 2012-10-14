# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'happy_importer/version'

Gem::Specification.new do |gem|
  gem.name          = "happy_importer"
  gem.version       = HappyImporter::VERSION
  gem.authors       = ["Klaus Zanders", "Bodo Tasche"]
  gem.email         = ["klaus.zanders@gmail.com", "bodo@wannawork.de"]
  gem.description   = %q{Importer für die OSM Daten in die Arango DB}
  gem.summary       = %q{Importer für die OSM Daten in die Arango DB}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'ashikawa-core'
  gem.add_runtime_dependency 'nokogiri'
  gem.add_runtime_dependency 'parsec'
  gem.add_runtime_dependency 'mysql2'

  gem.add_development_dependency "rspec", "~> 2.11.0"
end
