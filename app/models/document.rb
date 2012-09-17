class Document < ActiveRecord::Base
  #establish_connection "#{RAILS_ENV}" 

  belongs_to :category
  belongs_to :user
  validates :author, :presence => true
  validates :name, :presence => true
  validates_uniqueness_of :author, :scope => :name

  def fullname
    result = ''
    result = filename + '.' + filetype if filename && filetype
    result
  end

  def path
    result = ''
    result = CORE_DIR_FOR_CONVERSION + fullname if !fullname.to_s.empty?
    result
  end
end