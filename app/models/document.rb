class Document < ActiveRecord::Base
  #establish_connection "#{RAILS_ENV}" 

  belongs_to :category
  belongs_to :user
  validates :name, :presence => true

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
        begin
          FileUtils.rm(path, :force => true)
          FileUtils.rm_rf(CORE_DIR_TEXTS + filename + '/', secure: true)
        rescue Exception => e
          p "Error: Document.remove_core_document #{path}"
          false
        end
      end
  end
end