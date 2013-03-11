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
  is_error_show = false
  while(true)
    Handler.convert_to_text

    #remove unused files for removed documents
    begin
      Handler.garbage_collector
    rescue
      if !is_error_show
        p "Last convertion fininshed emergency. You need manually remove incorrect folder in the #{CORE_TMP_DIR}"
        is_error_show = true
      end
    end
    sleep 10*MINUTE
  end
end

desc "make indexation (content of documents) via sphinx"
task :make_index do
  Handler.make_index
end