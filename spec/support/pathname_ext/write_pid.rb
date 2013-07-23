require 'pathname'

module Pathname::WritePid
  def write_pid
    FileUtils.mkdir_p(dirname)
    open('w') { |io| io.puts Process.pid }
  end

  module ClassMethods
    def write_pid(arg)
      new(arg).write_pid
    end
  end

  Pathname.send(:include, self)
  Pathname.send(:extend, ClassMethods)
end
