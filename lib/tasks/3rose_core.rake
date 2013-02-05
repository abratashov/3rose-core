require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")
require 'tools'
require 'handler'

desc "creating need directories"
task :gen_core_directories do
  Dir.mkdir(CORE_DIR_DOCUMENTS) if !(Dir.exist?(CORE_DIR_DOCUMENTS))
  Dir.mkdir(CORE_DIR_ORIGINALS) if !(Dir.exist?(CORE_DIR_ORIGINALS))
  Dir.mkdir(CORE_DIR_TEXTS)     if !(Dir.exist?(CORE_DIR_TEXTS))
  Dir.mkdir(CORE_TMP_DIR)       if !(Dir.exist?(CORE_TMP_DIR))
  Dir.mkdir(CORE_SPHINX_DIR)    if !(Dir.exist?(CORE_SPHINX_DIR))
end

desc "start core worker"
task :core_worker do
  p "Core worker started =>"
  while(true)
    p Time.now
    Handler.convert_to_text
    sleep 10*MINUTE
  end
end

desc "make indexation (content of documents) via sphinx"
task :make_index do
  Handler.make_index
end