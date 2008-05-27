require File.dirname(__FILE__) + "/help"
require 'wink'
require 'data_mapper'

describe 'Wink' do

  it "is defined" do
    Object.should.const_defined :Wink
    Wink.should.not.be.nil
  end

  it "is versioned" do
    Wink.should.const_defined :VERSION
    Wink::VERSION.should.be.kind_of String
  end

  %w[Entry Article Bookmark Tag Tagging Comment].each do |class_name|
    it "defines #{class_name} model at the top level" do
      Object.should.const_defined class_name
      Object.const_get(class_name).should.not.be.nil
      Object.const_get(class_name).should < DataMapper::Persistence
    end
  end

  it "allows access to options via :options message" do
    Wink.should.respond_to :options
    Wink.options.should.not.be.nil
    Wink.options.author.should.be == 'John Doe'
    Wink.options.url.should.be == 'http://test.local'
  end

  it "allows access to options w/ [] and []=" do
    Wink.should.respond_to :[]
    Wink.should.respond_to :[]=
    Wink[:env].should.equal :test
    Wink[:url].should.equal 'http://test.local'
    Wink[:url] = 'http://changed'
    Wink[:url].should.equal 'http://changed'
    Wink[:url] = 'http://test.local'
    Wink[:url].should.equal 'http://test.local'
  end

  it "allows access to options like an OpenStruct" do
    Wink.should.respond_to :url
    Wink.url.should.equal 'http://test.local'
    Wink.url = 'http://changed'
    Wink.url.should.equal 'http://changed'
    Wink.url = 'http://test.local'
  end

  it "delegates option attribute read/write messages" do
    Wink.foo_bar.should.be.nil
    Wink.foo_bar = 'foo bar'
    Wink.foo_bar.should.equal 'foo bar'
    Wink.foo_bar = nil
  end

  it "does not advertise responses to unset options" do
    Wink.should.not.respond_to :some_unset_option
    Wink.should.respond_to :some_unset_option=
    Wink.some_unset_option.should.be.nil
    Wink.some_unset_option = 'Hello World.'
    Wink.should.respond_to :some_unset_option
    Wink.some_unset_option.should.equal 'Hello World.'
    Wink.some_unset_option = nil
  end

end
