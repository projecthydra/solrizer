require 'rubygems'
module Solrizer;end

require "solrizer/extractor"
# Dir[File.join(File.dirname(__FILE__),"solrizer","*.rb")].each {|file| require file }
Dir[File.join(File.dirname(__FILE__),"solrizer","*.rb")].each do |file| 
  require "solrizer/"+File.basename(file, File.extname(file))
end
