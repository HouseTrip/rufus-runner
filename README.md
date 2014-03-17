# rufus-runner

[![Build Status](https://travis-ci.org/HouseTrip/rufus-runner.png)](https://travis-ci.org/HouseTrip/rufus-runner)

Wraps [rufus-scheduler](http://github.com/jmettraux/rufus-scheduler) in a
standalone process, with job timing, logging, and safe defaults.


## Installation

Add this line to your application's Gemfile:

    gem 'rufus-runner'
    $ bundle

Or install it yourself as:

    $ gem install rufus-runner

Create a configuration file:

    # config/schedule.rb
    Rufus::TrackingScheduler.start do |scheduler|
      # sentinel job that keeps running to prove Rufus is still alive
      scheduler.run :name => 'no-op', :every => '60s' do
        Kernel.sleep(1e-3)
      end
    end

The `#run` method simply takes the same options as Rufus's `#every` method,
with these safe defaults:

    :mutex             => <m>       # because Rails is not thread-safe
    :timeout           => 60        # we don't want no long-running jobs, they should be DJ'd (seconds)
    :discard_past      => true      # don't catch up with past jobs
    :allow_overlapping => false     # don't try to run the same job twice simultaneously

Where `<m>` is a shared, global instance of `Mutex`.

Finally, run it:

    $ rufus-runner config/schedule.rb


### Rails

If you're running Rails, you might want to have an environment loaded in the
scheduler. Simply add on top of your schedule:

    # Rails 2
    require 'config/boot'
    require 'config/environment'

    # Rails 3
    require 'config/application'

When Rails is present, `rufus-runner` will call `ActiveRecord::Base.clear_active_connections!` after each job for you.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
