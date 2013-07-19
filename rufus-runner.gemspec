# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rufus-runner/version'

Gem::Specification.new do |gem|
  gem.name          = "rufus-runner"
  gem.version       = Rufus::Runner::VERSION
  gem.license       = 'MIT'
  gem.authors       = ["Julien Letessier"]
  gem.email         = ["julien.letessier@gmail.com"]
  gem.description   = %q{Wrapper process around rufus-scheduler}
  gem.summary       = %q{Wrapper process around rufus-scheduler}
  gem.homepage      = "http://github.com/mezis/rufus-runner"

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
  gem.add_development_dependency 'rspec-instafail'

  gem.files = %w(
    LICENSE.txt
    README.md
    bin/rufus-runner
    lib/pathname_ext/delete_if_exist.rb
    lib/pathname_ext/timestamp.rb
    lib/rufus-runner.rb
    lib/rufus-runner/tracking_scheduler.rb
    lib/rufus-runner/version.rb
    rufus-runner.gemspec
  )
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^spec/})
  gem.require_paths = ["lib"]
end
