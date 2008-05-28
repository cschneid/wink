require File.dirname(__FILE__) + "/help"
require 'wink/schema'

describe 'Wink::Schema' do

  before(:each) {
    setup_database
    @schema = Wink::Schema
  }

  after(:each)  { teardown_database }

  it 'responds to ::configure, ::create!, and ::drop!' do
    @schema.should.respond_to :configure
    @schema.should.respond_to :create!
    @schema.should.respond_to :drop!
  end

  it 'creates a welcome entry ...' do
    @schema.should.respond_to :create_welcome_entry!
    @schema.create_welcome_entry!
    entry = Entry.first(:slug => 'welcome')
    entry.should.not.be.nil
    @schema.create_welcome_entry!
  end

  it 'removes a welcome entry ...' do
    @schema.should.respond_to :remove_welcome_entry!
    @schema.create_welcome_entry!
    @schema.remove_welcome_entry!
    entry = Entry.first(:slug => 'welcome')
    entry.should.be.nil
  end

end


describe 'Database (DEPRECATED)' do

  it 'is defined' do
    Object.const_defined?(:Database).should.be.truthful
  end

  it 'responds to ::configure, ::create!, and ::drop!' do
    Database.should.respond_to :configure
    Database.should.respond_to :create!
    Database.should.respond_to :drop!
  end

end
