require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")
require 'tools'
require 'handler'

desc "creating need directories"
task :gen_core_directories do
  Dir.mkdir(CORE_DIR_DOCUMENTS)      if !(Dir.exist?(CORE_DIR_DOCUMENTS))
  Dir.mkdir(CORE_DIR_FOR_CONVERSION) if !(Dir.exist?(CORE_DIR_FOR_CONVERSION))
  Dir.mkdir(CORE_DIR_CONVERTED)      if !(Dir.exist?(CORE_DIR_CONVERTED))
  Dir.mkdir(CORE_TMP_DIR)            if !(Dir.exist?(CORE_TMP_DIR))
  Dir.mkdir(CORE_SPHINX_DIR)         if !(Dir.exist?(CORE_SPHINX_DIR))
end

desc "converted documents to text"
task :convert_to_text do
  p "Start convert_to_text ..."
  while(true)
    p 'while(true)'
    Handler.convert_to_text
    sleep 10*MINUTE
  end
end

desc "make indexation (content of documents) via sphinx"
task :make_sphinx_index do
  Handler.make_index
end