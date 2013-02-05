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
    result = CORE_DIR_ORIGINALS + fullname if !fullname.to_s.empty?
    result
  end

  def remove_core_document
    if !path.empty?
      FileUtils.rm(path, :force => true)
      FileUtils.rm_rf(CORE_DIR_TEXTS + filename + '/', secure: true)
    end
  end
end