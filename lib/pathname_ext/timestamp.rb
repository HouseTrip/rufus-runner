require 'pathname'

module Pathname::Timestamp
  def timestamp
    open('w') { |io| io.puts Time.now.to_i }
  end

  module ClassMethods
    def timestamp(arg)
      new(arg).timestamp
    end
  end

  Pathname.send(:include, self)
  Pathname.send(:extend, ClassMethods)
end
