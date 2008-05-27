require File.dirname(__FILE__) + "/help"
require 'fixtures'

describe 'Entry' do

  before(:each) { setup_database }
  after(:each)  { teardown_database }

  it 'finds no entries when none exist' do
    Entry.all.length.should.equal 0
  end

  it "can create a simple Article" do
    entry = create_article_from_pepys_diary('1659-01-01')
    entry.should.not.be nil
    entry.tags.should.be.empty
    entry.should.respond_to :tag_names
    entry.tag_names.should.be.empty
    entry.published.should.not.be.truthful
    entry.body.should.equal read_file_from_pepys_diary('1659-01-01')
    entry.updated_at.should.not.be nil
    entry.updated_at.should.be.kind_of DateTime
    entry.created_at.should.not.be nil
    entry.created_at.should.be.kind_of DateTime
  end

  it "finds an Article via Entry (STI)" do
    entry = create_article_from_pepys_diary('1659-01-01')
    entry.should.not.be nil
    found = Entry.first(:slug => '1659-01-01')
    found.should.not.be nil
    found.id.should.equal entry.id
    found.type.to_s.should.equal 'Article'
    found.type.should.equal Article
    found.body.should.equal read_file_from_pepys_diary('1659-01-01')
    found.updated_at.should.not.be nil
    found.updated_at.should.be.kind_of DateTime
    found.created_at.should.not.be nil
    found.created_at.should.be.kind_of DateTime
  end

  it "should not allow saving without a slug, title, and filter" do
    Entry.new.save.should.not.be.truthful
    Entry.new(:slug  => 'bar').save.should.not.be.truthful
    Entry.new(:title => 'Foo').save.should.not.be.truthful
    Entry.new(:slug => 'foo', :title => 'Foo').save.should.be.truthful
  end

  it "assumes a default text filter" do
    entry = Entry.new
    entry.filter.should.equal 'markdown'
  end

  it "accepts a variety of true/false values to publish=" do
    entry = Entry.new(:slug => 'test', :title => 'Test')
    entry.published?.should.be false
    entry.published = true
    entry.published?.should.be true
    entry.published = 1
    entry.published?.should.be true
    entry.published = 0
    entry.published?.should.be false
    entry.published = 'false'
    entry.published?.should.be false
    entry.published = 'true'
    entry.published?.should.be true
  end

  it 'coerces the published attr to a boolean out of the database' do
    entry = Entry.new(:slug => 'test', :title => 'Test')
    entry.save.should.be.truthful

    (entry = Entry.first(:slug => 'test'))
    entry.should.not.be.nil
    entry.published.should.equal false
    entry.published = 1
    entry.published.should.equal true
    entry.save.should.be.truthful

    (entry = Entry.first(:slug => 'test'))
    entry.should.not.be.nil
    entry.published.should.equal true
  end

  it 'updates created and updated dates when publishing' do
    original = Entry.new(:slug => 'test', :title => 'Test')
    original.save.should.be.truthful
    original.created_at.should.not.be.nil
    original.updated_at.should.not.be.nil
    created_at, updated_at = original.created_at, original.updated_at
    sleep 1.0
    entry = Entry.first(:slug => 'test')
    entry.draft?.should.be true
    entry.created_at.should == created_at
    entry.updated_at.should == updated_at
    entry.published = true
    # entry.save.should.be.truthful
    entry.created_at.should.be > created_at
    entry.updated_at.should.be > updated_at
  end


end
