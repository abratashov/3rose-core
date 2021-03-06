# -*- encoding : utf-8 -*-
require 'tools'
require 'zip/zip'
require 'zlib'
require 'logger'

class Handler

  class << self
    def convert_to_text
      logger = Logger.new(File.open('log.log', 'a'))
      docs = Document.where("state = #{State.find_by_name('ACCEPT_FOR_CONVERT').code}")
      p docs.length
      error_counter = 0
      docs.each do |doc|
        logger.info ''
        logger.info "==================== #{doc.name} ===================="
        logger.info Time.now
        if doc.filetype == 'zip'
          document_name = uncompress_document(doc, logger)
          document_path = CORE_TMP_DIR + document_name
        elsif DOC_TYPES.include?(doc.filetype)
          document_name = doc.fullname
          document_path = doc.path
        else
          doc.update_attributes({:state => State.find_by_name('ERR_UNKNOWN_DOCUMENT_TYPE').code})
        end

        if document_name && !document_name.empty?
          logger.info document_path
          doctype = document_path.sub(/^.*\./,'')
          doc.update_attributes({:doctype => doctype}) if doctype && document_path != CORE_TMP_DIR
          last_error = false
          if DOC_TYPES.include?(doctype)
            begin
              logger.info doc.filetype
              if doc.filetype != 'pdf'
                if doc.doctype != 'pdf'
                  Docsplit.extract_pdf(document_path, :output => CORE_TMP_DIR)
                end
                pdf_path = CORE_TMP_DIR + make_need_filename_extension(document_name, 'pdf')
              else
                pdf_path = doc.path
              end
              logger.info "PDF path: #{pdf_path}"
              num_pages = 0
              num_pages = PdfUtils.info(pdf_path).pages
              logger.info "Pages: #{num_pages}"
              if num_pages
                #dirname = make_need_filename_extension(doc.filename, '')
                dirname = doc.filename
                FileUtils.rm_rf(CORE_DIR_TEXTS + dirname)
                Dir.mkdir(CORE_DIR_TEXTS + dirname) if !(Dir.exist?(CORE_DIR_TEXTS + dirname))
                Docsplit::extract_text(pdf_path, :ocr => false, :pages => 'all', :output => CORE_DIR_TEXTS + dirname)
                delete_last_byte_at_document(doc.filename, num_pages)
                doc.update_attributes({:pages => num_pages})
                doc.update_attributes({:state => State.find_by_name('CONVERTED_ON_CORE').code})
              else
                doc.update_attributes({:state => State.find_by_name('ERR_CANNOT_CONVERT_DOCUMENT').code})
              end
              FileUtils.rm(pdf_path, :force => true) if num_pages && doc.filetype != 'pdf'
            rescue
              last_error = true
              error_counter += 1
              logger.error "CONVERTING ERROR (#{error_counter})"
              doc.update_attributes({:state => State.find_by_name('ERR_CANNOT_CONVERT_DOCUMENT').code})
            end
            if last_error
              if error_counter > 3
                #%x[xkbevd -bg]
                msg = 'Many errors have occured. Need to restart converting.'
                logger.error msg
                raise msg
              end
            else
              error_counter = 0
            end
          else
            logger.error 'ERR_UNKNOWN_DOCUMENT_TYPE'
            doc.update_attributes({:state => State.find_by_name('ERR_UNKNOWN_DOCUMENT_TYPE').code})
          end
        end
      end
    end

    def make_index
      p "#{Time.now} Making index..."
      if Handler.gen_sphinx_xml
        %x[sudo pkill searchd]
        %x[sudo indexer --all]
        %x[sudo /usr/local/bin/searchd]
        p "#{Time.now} Index had been made"
        # set index semaphore
      else
        p "#{Time.now} ERROR during generating xml"
      end
    end

#    private

    def uncompress_document(doc, logger)
      filepath = ""
      begin
        source = doc.path
        target = CORE_TMP_DIR
        FileUtils.rm_rf(target, secure: true) # delete tmp/
        Dir.mkdir(target)                     # create tmp/
        files = []
        Zip::ZipFile.open(source) do |zipfile|
          dir = zipfile
          dir.entries.each do |entry|
            begin
              filepath = "#{entry}"
              zipfile.extract(entry, "#{target}#{filepath}")
              extension = filepath.sub(/^.*\./,'')
              new_filename = (doc.filename + '.' + extension).downcase
              File.rename("#{target}#{filepath}", "#{target}#{new_filename}")
              filepath = new_filename
              files << File.read("#{target}#{filepath}")
            rescue
              FileUtils.rm("#{target}#{entry}")
              logger.error "Error #{$!}#{entry}"
              doc.update_attributes({:state => State.find_by_name('ERR_UNCOMPRESS_DOCUMENT').code})
            end
          end
        end
        if files.length != 1
          doc.update_attributes({:state => State.find_by_name('ERR_UNCOMPRESS_DOCUMENT').code})
          filepath = ""
        end
      rescue
        logger.error "UNCOMPRESSION ERROR"
        doc.update_attributes({:state => State.find_by_name('ERR_UNCOMPRESS_DOCUMENT').code})
      end
      filepath
    end

    def gen_sphinx_xml
      f = File.new(CORE_XML_PATH, 'w+')
      f.syswrite(
%q(<?xml version="1.0" encoding="utf-8"?>
  <sphinx:docset>
  <sphinx:schema>
    <sphinx:field name="content"/>
    <sphinx:attr name="category_id" type="int" bits="16" default="0"/>
  </sphinx:schema>
))
      select = "state = #{State.find_by_name('CONVERTED').code}"
      select += " OR state = #{State.find_by_name('LAST_INDEXED').code}"
      select += " OR state = #{State.find_by_name('INDEXED').code}"
      docs = Document.where(select)
      docs.each do |doc|
        pages = doc.pages
        dirname = make_need_filename_extension(doc.filename, '')
        pages.times do |page|
          filename = make_filename_of_txt_page(doc.filename, page + 1)
          atom_id = doc.id*MAX_PAGES + (page + 1)
          #Example: '45000'+'105' => 45000105, [id + page] atomic el for indexation
          f.syswrite("  <sphinx:document id=" + "\"#{atom_id}\"" + ">" + "\n")
          f.syswrite("  <category_id>#{doc.category_id}</category_id>\n")
          f.syswrite("    <content>" + "\n")
          f.syswrite(IO.read(CORE_DIR_TEXTS + dirname + '/' + filename).delete "<" ">" "&" "\u0001" "\u25A0" "\a")
          f.syswrite("\n")
          f.syswrite("    </content>" + "\n")
          f.syswrite("  </sphinx:document>" + "\n")
          f.syswrite("\n")
        end
        if doc.state == State.find_by_name('CONVERTED').code
          doc.update_attributes({:state => State.find_by_name('LAST_INDEXED').code})
        elsif doc.state == State.find_by_name('LAST_INDEXED').code
          doc.update_attributes({:state => State.find_by_name('INDEXED').code})
        end
      end
      f.syswrite("</sphinx:docset>")
      f.close

      docs = Document.where("state = #{State.find_by_name('REMOVED').code}")
      docs.each do |doc|
        doc.update_attributes({:state => State.find_by_name('CONFIRM_REMOVED').code})
        doc.remove_core_document
      end
      p "#{Time.now} XML had been generated"
      cats = Category.where("state = #{State.find_by_name('REMOVED').code}")
      cats.each{|cat| cat.update_attributes({:state => State.find_by_name('CONFIRM_REMOVED').code})}
      true
    # rescue
      # false
    end

    def garbage_collector
      if !IS_APP_SHARE_FOLDER
        err1 = State.find_by_name('ERR_CANNOT_CONVERT_DOCUMENT').code
        err2 = State.find_by_name('ERR_UNCOMPRESS_DOCUMENT').code
        err3 = State.find_by_name('ERR_UNKNOWN_DOCUMENT_TYPE').code
        ind1 = State.find_by_name('LAST_INDEXED').code
        ind2 = State.find_by_name('INDEXED').code
        documents = Document.where('state = ? OR state = ? OR state = ? OR state = ? OR state = ?', err1, err2, err3, ind1, ind2)
        documents.each{|doc| FileUtils.rm(doc.path, :force => true)}
      end

      documents = Document.find(:all)
      document_codes = []
      documents = documents ? documents : []
      documents.each{|doc| document_codes << doc.filename.split(/[_]/)[-1]}
      # example: "ep_blavatsky____voice_of_the_silence_79570".split(/[\._]/)[-1] => "79570"
      files = Dir.entries(CORE_DIR_ORIGINALS)
      files.delete('.')
      files.delete('..')
      files.each do |file|
        if !document_codes.include?(file.split(/[\._]/)[-2])
          FileUtils.rm(CORE_DIR_ORIGINALS + file, :force => true)
        end
      end

      folders = Dir.entries(CORE_DIR_TEXTS)
      folders.delete('.')
      folders.delete('..')
      folders.each do |folder|
        if !document_codes.include?(folder.split(/[_]/)[-1])
          FileUtils.rm_rf(CORE_DIR_TEXTS + folder + '/', :secure => true)
        end
      end

      documents = Document.where('state = ?', State.find_by_name('CONVERTED_ON_CORE').code)
      document_codes = []
      documents = documents ? documents : []
      documents.each{|doc| document_codes << doc.filename.split(/[_]/)[-1]}
      files = Dir.entries(CORE_TMP_DIR)
      files.delete('.')
      files.delete('..')
      files.each do |file|
        if !document_codes.include?(file.split(/[\._]/)[-2])
          FileUtils.rm(CORE_TMP_DIR + file, :force => true)
        end
      end
    end
  end

end