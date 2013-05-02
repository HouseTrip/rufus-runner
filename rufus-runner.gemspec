# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rufus-runner/version'

Gem::Specification.new do |gem|
  gem.name          = "rufus-runner"
  gem.version       = Rufus::Runner::VERSION
  gem.authors       = ["Julien Letessier"]
  gem.email         = ["julien.letessier@gmail.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.add_runtime_dependency 'eventmachine'
  gem.add_runtime_dependency 'rufus-scheduler', '~> 2'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '~> 2'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'rb-inotify'
  gem.add_development_dependency 'rb-fsevent'
  gem.add_development_dependency 'rb-fchange'
  gem.add_development_dependency 'terminal-notifier-guard'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'pry-nav'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
