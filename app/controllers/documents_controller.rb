require 'carrierwave'
#require 'tools'
#require 'fileutils'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'handler'
require 'riddle'

class DocumentsController < ApplicationController
  layout 'application'

  def load
    status = false
    document = Document.find(params[:did].to_i) if params[:did]
    if document && params[:f] && !IS_APP_SHARE_FOLDER
      FileUtils.rm(document.path, :force => true) if !document.filename.empty?
      #Remove all text page (did)!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      document_uploader = DocumentUploader.new
      document_uploader.store!(params[:f])
      status = true if document.update_attributes({:state => State.find_by_name('ACCEPT_FOR_CONVERT').code})
    end
    render :json => {:success => status}.to_json
  end

  def remove
    # document = Document.find(params[:did].to_i) if params[:did]
  end

  def status
    # result = {:status => 0}
    # doc = Document.where("id = #{params[:did]}").first if params[:did]
    # result[:status] = doc.status if doc
    # render :json => result
  end

  def get
    document = Document.where("id = #{params[:did]}").first if params[:did]
    if document && document.state == State.find_by_name('CONVERTED_ON_CORE').code && !IS_APP_SHARE_FOLDER
      folder = CORE_DIR_TEXTS + document.filename #"Users/me/Desktop/stuff_to_zip"
      input_filenames = generate_pages(document)#['image.jpg', 'description.txt', 'stats.csv']
      zipfile_name = CORE_TMP_DIR + document.filename + '.zip' #"/Users/me/Desktop/archive.zip"
      FileUtils.rm zipfile_name, :force=>true
      Zip::ZipFile.open(zipfile_name, Zip::ZipFile::CREATE) do |zipfile|
        input_filenames.each do |filename|
          # Two arguments:
          # - The name of the file as it will appear in the archive
          # - The original file, including the path to find it
          zipfile.add(filename, folder + '/'+ filename)
        end
      end
      #send_file '/home/alex/Projects/3rose/core_documents/tmp/content.zip'
      send_file zipfile_name
      #send_file document.path
    end
  end

  def generate_pages(doc)
    res = []
    doc.pages.times {|num| res << doc.filename + "_#{num + 1}.txt"}
    res
  end

  def compress(path)
    # path.sub!(%r[/$],'')
    # archive = File.join(path, File.basename(path))+'.zip'
    # FileUtils.rm archive, :force=>true
#   
    # Zip::ZipFile.open(archive, 'w') do |zipfile|
      # Dir["#{path}/**/**"].reject{|f|f==archive}.each do |file|
        # zipfile.add(file.sub(path+'/',''),file)
      # end
    # end
  end
#no! only crontask
#  def convert
#    Handler.convert_to_text
#    Handler.gen_sphinx_xml
#    Handler.make_index
#  end

  def converted
    #doc = Document.where("id = #{params[:did]}" AND "status = #{Status::CONVERTED}").first if params[:did]
    #result[:status] = doc.status if doc
    #param[:did]
#    result = {:status => 0}
#    doc = Document.where("id = #{params[:did]}").first if params[:did]
#    result[:status] = doc.status if doc
#    render :json => result
  end

  def search
    p params[:search]
    p params[:categories]
    result = []
    search_string = params[:search]
    categories = params[:categories] ? params[:categories] : []
    if search_string
      docs_pages = {}
      sphinx = Riddle::Client.new

      if params[:sort_by] && params[:sort_by] == 'category'
        p '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! if params[:sort_by] && params[:sort_by] == category' 
        sphinx.sort_mode  = :extended
        sphinx.sort_by    = "category_id DESC"
      end
      sphinx.match_mode = :extended
      #sphinx.match_mode = :all

      sphinx.limit = params[:limit] ? params[:limit] : 50
      sphinx.offset = params[:offset] ? params[:offset] : 0

      unless categories.empty?
        p 'here----------------------------'
        p categories
        sphinx.filters << Riddle::Client::Filter.new("category_id", categories, false)
      end
      sphinx_results = sphinx.query(search_string)
      p 'ppppppppppppppppppppppp'
      p sphinx_results
      sphinx_results[:matches].each do |match|
        id = (match[:doc]/MAX_PAGES).to_i
        if !(docs_pages[id])
          docs_pages[id] = []
        end
        docs_pages[id] << {
          :page => (match[:doc] - ((match[:doc]/MAX_PAGES).to_i)*MAX_PAGES),
          :weight => match[:weight]
        }
      end
      docs_pages.each{|key, value| result << { :document_id => key, :pages=> value} }
    end
    render :json => result.to_json
  end
end