# -*- encoding : utf-8 -*-
require 'tools'
require 'zip/zip'
require 'zlib'

class Handler

  class << self
    def convert_to_text
      docs = Document.where("state = #{State.find_by_name('ACCEPT_FOR_CONVERT').code}")
      docs.each do |doc|
        if doc.filetype == 'zip'
          document_name = uncompress_document(doc)
        elsif DOC_TYPES.include?(doc.filetype)
          document_name = doc.path
        else
          doc.update_attributes({:state => State.find_by_name('ERR_UNKNOWN_DOCUMENT_TYPE').code})
          document_name = ''
        end
        unless document_name.empty?
          p '====================================================='
          p document_name
          begin
            Docsplit.extract_pdf(CORE_TMP_DIR + document_name, :output => CORE_TMP_DIR)
            pdf_name = make_need_filename_extension(document_name, 'pdf')
            #pdf_name = doc.filename + '.pdf'
            num_pages = 0
            num_pages = PdfUtils.info(CORE_TMP_DIR + pdf_name).pages
            if num_pages
              #dirname = make_need_filename_extension(doc.filename, '')
              dirname = doc.filename
              FileUtils.rm_rf(CORE_DIR_CONVERTED + dirname)
              Dir.mkdir(CORE_DIR_CONVERTED + dirname) if !(Dir.exist?(CORE_DIR_CONVERTED + dirname))
              Docsplit::extract_text(CORE_TMP_DIR + pdf_name, :ocr => false, :pages => 'all', :output => CORE_DIR_CONVERTED + dirname)
              delete_last_byte_at_document(doc.filename, num_pages)
              doc.update_attributes({:pages => num_pages})
              doc.update_attributes({:state => State.find_by_name('CONVERTED_ON_CORE').code})
            else
              doc.update_attributes({:state => State.find_by_name('ERR_CANNOT_CONVERT_DOCUMENT').code})
            end
            FileUtils.rm(CORE_TMP_DIR + pdf_name, :force => true) if num_pages
          rescue
           p "CONVERTING ERROR"
           doc.update_attributes({:state => State.find_by_name('ERR_CANNOT_CONVERT_DOCUMENT').code})
          end
        end
      end
    end

    def uncompress_document(doc)
      filepath = ""
      # begin
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
              puts "Error #{$!}#{entry}"
            end
          end
        end
        if files.length != 1
          doc.update_attributes({:state => State.find_by_name('ERR_UNCOMPRESS_DOCUMENT').code})
          filepath = ""
        end
      # rescue
        # p "UNCOMPRESSION ERROR"
        # doc.update_attributes({:state => State.find_by_name('ERR_UNCOMPRESS_DOCUMENT').code})
      # end
      p 'end------------'
      p filepath
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
  </sphinx:schema>) + "\n")
      f.syswrite("\n")
      docs = Document.where("state = #{State.find_by_name('CONVERTED').code} OR state = #{State.find_by_name('IN_INDEXING').code}")
      docs.each do |doc|
        pages = doc.pages
        dirname = make_need_filename_extension(doc.filename, '')
        pages.times do |page|
          filename = make_filename_of_txt_page(doc.filename, page + 1)
          atom_id = doc.id*MAX_DOCUMENTS + (page + 1)
          #Example: '45000'+'105' => 45000105, [id + page] atomic el for indexation
          f.syswrite("  <sphinx:document id=" + "\"#{atom_id}\"" + ">" + "\n")
          f.syswrite("  <category_id>#{doc.category_id}</category_id>\n")
          f.syswrite("    <content>" + "\n")
          f.syswrite(IO.read(CORE_DIR_CONVERTED + dirname + '/' + filename).delete "<" ">" "&")
          f.syswrite("\n")
          f.syswrite("    </content>" + "\n")
          f.syswrite("  </sphinx:document>" + "\n")
          f.syswrite("\n")
        end
        doc.update_attributes({:state => State.find_by_name('IN_INDEXING').code})
      end
      f.syswrite("</sphinx:docset>")
      f.close
      true
    rescue
      false
    end

    def make_index
      if Handler.gen_sphinx_xml
        #%x[sudo indexer --all]
        #set index semaphore
      else
        p 'Error during generating xml'
      end
    end
    
    def garbage_collector #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
      #if happen failure during processing and we have zombi-state
      #we should reset state to UPDATED
    end
#    def message(userID, partnerID, post_key, text)
#      hash = {
#        'senderID' => userID,
#        'recipientID' => partnerID,
#        'body' => text,
#        'postKey' => post_key
#      }
#      response = request('message', hash)
#      ActiveSupport::JSON.decode(response)
#    end

#    def request(path, data)
#      params = {}
#      url = "#{base_url}/social/#{path}"
#      data.each do |k,v|
#        v = JSON.generate(v) if v.is_a?(Hash)
#        v = v.to_s if !v.is_a?(File)
#        params[k.to_s] = v
#      end
#      response = RestClient.post(url, params)
#    end
  end

end