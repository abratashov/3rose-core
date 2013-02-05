def make_need_filename_extension(old_filename, new_ext)
  filename = old_filename.gsub(/\..*$/,'')
  new_filename = filename
  new_filename = new_filename + '.' + new_ext if !new_ext.empty?
  new_filename
end

def make_filename_of_txt_page(old_filename, page)
  filename = old_filename.gsub(/\..*$/,'')
  new_filename = filename + '_' + page.to_s + '.' + 'txt'
  new_filename
end

#def make_page(num_page, max_page)
#  smax = max_page.to_s
#  snew = num_page.to_s
#  return snew if max_page < num_page
#  while (snew.length != smax.length)
#    snew = '0' + snew
#  end
#  snew
#end

#fix for jodconverter: delete last ugly byte in converted text page
def delete_last_byte_at_document(filename, num_pages)
  num_pages.to_i.times do |page|
    #filename_page = make_filename_of_txt_page(filename, page + 1)
    #filename_page = filename + '_' + make_page(page + 1, num_pages).to_s + '.txt'
    filename_page = filename + '_' + (page + 1).to_s + '.txt'
    #dirname = make_need_filename_extension(filename, '')
    dirname = filename
    file = File.new(CORE_DIR_TEXTS + dirname + '/' + filename_page, 'a+')
    if (file.size > 0)
      file.seek(file.size - 1)
      last_byte = file.getc
      if last_byte == "\f"
        file.truncate(file.size - 1)
      end
    end
    file.close
  end
end