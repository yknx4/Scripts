#!/usr/bin/ruby
#All Requires
require 'json'
require 'net/http'
require 'fileutils'
require 'diffy'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

#Const
content_path = 'sites/';
tmp_file_path = 'data.tmp';

def generateFileName (url)
  URI.encode(url)
end

def sanitize_filename(filename)
  # Split the name when finding a period which is preceded by some
  # character, and is followed by some character other than a period,
  # if there is no following period that is followed by something
  # other than a period (yeah, confusing, I know)
  fn = filename.split /(?<=.)\.(?=[^.])(?!.*\.[^.])/m

  # We now have one or two parts (depending on whether we could find
  # a suitable period). For each of these parts, replace any unwanted
  # sequence of characters with an underscore
  fn.map! { |s| s.gsub /[^a-z0-9\-]+/i, '_' }

  # Finally, join the parts with a period and return the result
  return fn.join '.'
end

def same?(original_string, compare_to)
  original_string == compare_to ? true : false
end

def sentence(original, compare, num_errors=0)

  original_array = original.split(' ')
  comparable_array = compare.split(' ')
  original_exclusive ||= []

  new_array = original_array.each.with_index.with_object([]) do |(word, index) , array|
    #array << "The word '#{word}' at position #{index + 1} is different from '#{comparable_array[index]}' " if word != comparable_array[index]
    array << word if word != comparable_array[index]
  end

  return new_array[num_errors] || 'No differences detected'

end

#IO
configFile = File.read('config.json')
lastModifiedFile = File.read('storage.json')

#Load config
config = JSON.parse(configFile);
lastModified = JSON.parse(lastModifiedFile);

links = config['links'];
modified_sites = []
#Web Request

links.each do |link|

  #Variables
  urlString = link['url']
  url = URI.parse(urlString)
  globalSearchTerms = config['search_terms']
  localSearchTerms = link['search_terms']
  searchTerms = globalSearchTerms+localSearchTerms


  puts link
  req = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port) {|http|
    http.request(req)
  }
  #puts res.body
  fileName = sanitize_filename(generateFileName(urlString))
  fileFullPath = content_path+fileName
  page_content = res.body.force_encoding("UTF-8")

  puts "\n"

  if File.exist?(fileFullPath) then
    existing_content = File.read(fileFullPath);
    File.write(tmp_file_path,page_content)
    if !FileUtils.compare_file(fileFullPath,tmp_file_path)
      puts urlString + " has changed."
      puts 'Comparing '+existing_content.length.to_s+  ' to '+page_content.length.to_s+'.'
      difference =  sentence(page_content,existing_content)
      File.write('difference_'+fileName+'.txt',difference)
      searchTerms.any? { |word|
        if difference.include?(word) then
          puts word+' => it has changed.'
          modified_sites.push Hash["data" => link, "diff" => difference]
        end }
        puts 'Changes: '+difference
      end
    end
    File.write(fileFullPath,page_content)
    # res.header.each_header {|key,value| puts "#{key} = #{value}" }
  end
puts "\n\n\n Modified sites:"
puts modified_sites
modified_sites.each do |link|
  urlString = link['data']['url']
  #message = urlString+' was updated with the following terms: '+link['diff']
  title = link['data']['title'];
  message = 'Site was updated with the following terms: '+link['diff']
#  command = `terminal-notifier -title 'Site updated' -message '`+urlString+` was updated. It found the following terms: `+link['diff']+`' -open '`+urlString+`'`
command = `/Users/yknx4/.rbenv/shims/terminal-notifier -title '#{title} updated' -message '#{message}: ' -open "#{urlString}"`
end
