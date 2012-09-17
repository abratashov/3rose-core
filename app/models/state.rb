class State < ActiveRecord::Base
  validates_uniqueness_of :name, :scope => :code
end