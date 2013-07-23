require 'pathname'

module Pathname::DeleteIfExist
  def delete_if_exist
    delete if exist?
  end

  Pathname.send(:include, self)
end
