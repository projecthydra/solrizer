require 'solr'
require 'solrizer/extractor'
require 'solrizer/repository'

module Solrizer::Fedora
class Indexer  
  #
  # Class variables
  #
  @@unique_id = 0

  def self.unique_id
    @@unique_id
  end

  #
  # Member variables
  #
  attr_accessor :connection, :extractor, :index_full_text

  #
  # This method performs initialization tasks
  #
  def initialize( opts={} )
    @@index_list = false unless defined?(@@index_list)
    @extractor = ::Solrizer::Extractor.new
    
    if opts[:index_full_text] == true || opts[:index_full_text] == "true"
      @index_full_text = true 
    else
      @index_full_text = false 
    end
    
    connect
  end

  #
  # This method connects to the Solr instance
  #
  def connect
    
    if ActiveFedora.fedora_config.empty?
      ActiveFedora.init
    end
    
    if defined?(Blacklight)
      solr_config = Blacklight.solr_config
    else
      
      if defined?(RAILS_ROOT)
        config_path = File.join(RAILS_ROOT, "config")
        yaml = YAML.load(File.open(File.join(config_path, "solr.yml")))
        solr_config = yaml[RAILS_ENV]
        puts solr_config.inspect
      else
        config_path = File.join(File.dirname(__FILE__), "..", "..", "..", "config")
        yaml = YAML.load(File.open(File.join(config_path, "solr.yml")))
        
        
        if ENV["environment"].nil?
          environment = "development"
        else
          environment = ENV["environment"]
        end
        
        solr_config = yaml[environment]
        puts solr_config.inspect
      end
      
    end
        
    if index_full_text == true
      url = solr_config['fulltext']['url']
    elsif solr_config.has_key?("default")
      url = solr_config['default']['url']
    else
      url = solr_config['url']
    end
    @connection = Solr::Connection.new(url, :autocommit => :on )
  end

  #
  # This method extracts the facet categories from the given Fedora object's external tag datastream
  #
  def extract_xml_to_solr( obj, ds_name, solr_doc=Solr::Document.new )
    xml_ds = Repository.get_datastream( obj, ds_name )
    extractor.xml_to_solr( xml_ds.content, solr_doc )
  end
  
  #
  #
  #
  def extract_rels_ext( obj, ds_name, solr_doc=Solr::Document.new )
    rels_ext_ds = Repository.get_datastream( obj, ds_name )
    extractor.extract_rels_ext( rels_ext_ds.content, solr_doc )
  end
  
  #
  # This method generates the month and day facets from the date_t in solr_doc
  #
  
  def generate_dates(solr_doc)
    
    # This will check for valid dates, but it seems most of the dates are currently invalid....
    #date_check =  /^(19|20)\d\d([- \/.])(0[1-9]|1[012])\2(0[1-9]|[12][0-9]|3[01])/

   #if there is not date_t, add on with easy-to-find value
   if solr_doc[:date_t].nil?
        solr_doc << Solr::Field.new( :date_t => "9999-99-99")
   end #if

    # unless date_check !~  solr_doc[:date_t]     
    date_obj = Date._parse(solr_doc[:date_t])
    
    if date_obj[:mon].nil? 
       solr_doc << Solr::Field.new(:month_facet => 99)
    elsif 0 < date_obj[:mon] && date_obj[:mon] < 13
      solr_doc << Solr::Field.new( :month_facet => date_obj[:mon].to_s.rjust(2, '0'))
    else
      solr_doc << Solr::Field.new( :month_facet => 99)
    end
      
    if  date_obj[:mday].nil?
      solr_doc << Solr::Field.new( :day_facet => 99)
    elsif 0 < date_obj[:mday] && date_obj[:mday] < 32   
      solr_doc << Solr::Field.new( :day_facet => date_obj[:mday].to_s.rjust(2, '0'))
    else
       solr_doc << Solr::Field.new( :day_facet => 99)
    end
    
    return solr_doc
#      end
        
  end
  
  
  #
  # This method creates a Solr-formatted XML document
  #
  def create_document( obj )        
    
    solr_doc = Solr::Document.new
    
    model_klazz_array = ActiveFedora::ContentModel.known_models_for( obj )
    model_klazz_array.delete(ActiveFedora::Base)
    
    # If the object was passed in as an ActiveFedora::Base, call to_solr in order to get the base field entries from ActiveFedora::Base
    # Otherwise, the object was passed in as a model instance other than ActiveFedora::Base,so call its to_solr method & allow it to insert the fields from ActiveFedora::Base
    if obj.class == ActiveFedora::Base
      solr_doc = obj.to_solr(solr_doc)
      puts "  added base fields from #{obj.class.to_s}"
    else
      solr_doc = obj.to_solr(solr_doc)
      model_klazz_array.delete(obj.class)
      puts "    added base fields from #{obj.class.to_s} and model fields from #{obj.class.to_s}"
    end
   
    # Load the object as an instance of each of its other models and get the corresponding solr fields
    # Include :model_only=>true in the options in order to avoid adding the metadata from ActiveFedora::Base every time.
    model_klazz_array.each do |klazz|
      instance = klazz.load_instance(obj.pid)
      solr_doc = instance.to_solr(solr_doc, :model_only=>true)
      puts "  added solr fields from #{klazz.to_s}"
    end
    
    solr_doc << Solr::Field.new( :id_t => "#{obj.pid}" )
    solr_doc << Solr::Field.new( :id => "#{obj.pid}" ) unless solr_doc[:id]
    
    # increment the unique id to ensure that all documents in the search index are unique
    @@unique_id += 1

    return solr_doc
  end

  #
  # This method adds a document to the Solr search index
  #
  def index( obj )
   # print "Indexing '#{obj.pid}'..."
    begin
      
      solr_doc = create_document( obj )
      connection.add( solr_doc )
 
     # puts connection.url
     #puts solr_doc
     #  puts "done"
   
    # rescue Exception => e
    #    p "unable to index #{obj.pid}.  Failed with #{e.inspect}"
    end
   
  end

  #
  # This method queries the Solr search index and returns a response
  #
  def query( query_str )
    response = conn.query( query_str )
  end
  

  private :connect, :create_document

  def class_exists?(class_name)
    klass = Module.const_get(class_name)
    return klass.is_a?(Class)
  rescue NameError
    return false
  end
  
end
end
