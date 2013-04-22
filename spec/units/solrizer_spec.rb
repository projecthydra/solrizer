require 'spec_helper'
require 'time'

describe Solrizer do
  describe ".insert_field" do
    describe "on an empty document" do
      let(:doc) { Hash.new }
      it "should insert a field with the default (stored_searchable) indexer" do
        Solrizer.insert_field(doc, 'foo', 'A name')
        doc.should == {'foo_tesim' => ['A name']}
      end
      it "should insert a field with multiple indexers" do
        Solrizer.insert_field(doc, 'foo', 'A name', :sortable, :facetable)
        doc.should == {'foo_si' => ['A name'], 'foo_sim' => ['A name']}
      end
      it "should insert Dates" do
        Solrizer.insert_field(doc, 'foo', Date.parse('2013-01-13'))
        doc.should == {'foo_dtsim' => ["2013-01-13T00:00:00Z"]}
      end
      it "should insert Times" do
        Solrizer.insert_field(doc, 'foo', Time.parse('2013-01-13T22:45:56+06:00'))
        doc.should == {'foo_dtsim' => ["2013-01-13T16:45:56Z"]}
      end

      it "should insert multiple values" do
        Solrizer.insert_field(doc, 'foo', ['A name', 'B name'], :sortable, :facetable)
        # NOTE:  is this desired behavior for non-multivalued fields, like :sortable ?
        doc.should == {'foo_si' => ['A name', 'B name'], 'foo_sim' => ['A name', 'B name']}
      end
    end

    describe "on a document with values" do
      before{ @doc = {'foo_si' => ['A name'], 'foo_sim' => ['A name']}}

      it "should not overwrite values that exist before" do
        Solrizer.insert_field(@doc, 'foo', 'B name', :sortable, :facetable)
        @doc.should == {'foo_si' => ['A name', 'B name'], 'foo_sim' => ['A name', 'B name']}
      end
    end
  end
  describe ".set_field" do
    describe "on a document with values" do
      before{ @doc = {'foo_si' => ['A name'], 'foo_sim' => ['A name']}}

      it "should overwrite values that exist before" do
        Solrizer.set_field(@doc, 'foo', 'B name', :sortable, :facetable)
        @doc.should == {'foo_si' => ['B name'], 'foo_sim' => ['B name']}
      end
    end
  end

  describe ".solr_name" do
    it "should delegate to default_field_mapper" do
        Solrizer.solr_name('foo', type: :string).should == "foo_tesim"
        Solrizer.solr_name('foo', :sortable).should == "foo_si"
        Solrizer.solr_name('foo', :date).should == "foo_dtsim"
        Solrizer.solr_name('foo', :symbol).should == "foo_ssim"
    end
  end
end
