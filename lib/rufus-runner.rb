require "rufus-runner/version"
require "rufus-runner/tracking_scheduler"
require "rufus-runner/locking_io_decorator"

unless $stdout.is_a?(Rufus::LockingIODecorator)
  $stdout = Rufus::LockingIODecorator.new($stdout)
end
