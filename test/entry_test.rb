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

  it 'takes a block when creating with ::new' do
    block_run = false
    entry =
      Entry.new :slug => 'test' do |entry|
        block_run = true
        entry.title = 'Test Entry'
        entry.body = 'nothing to see here'
      end
    block_run.should.equal true
    entry.slug.should.equal 'test'
    entry.title.should.equal 'Test Entry'
    entry.body.should.equal 'nothing to see here'
  end

  it 'takes a block when creating with ::create' do
    block_run = false
    entry =
      Entry.create :slug => 'test' do |entry|
        block_run = true
        entry.should.be.new_record
        entry.title = 'Test Entry'
        entry.body = 'nothing to see here'
      end
    block_run.should.equal true
    entry.should.not.be.new_record
    entry.slug.should.equal 'test'
    entry.title.should.equal 'Test Entry'
    entry.body.should.equal 'nothing to see here'
  end

  it 'takes a block when creating with ::create!' do
    block_run = false
    entry =
      Entry.create! :slug => 'test' do |entry|
        block_run = true
        entry.should.be.new_record
        entry.title = 'Test Entry'
        entry.body = 'nothing to see here'
      end
    block_run.should.equal true
    entry.should.not.be.new_record
    entry.slug.should.equal 'test'
    entry.title.should.equal 'Test Entry'
    entry.body.should.equal 'nothing to see here'
  end

  it "find only Articles via Article::first (STI)" do
    entry = create_article_from_pepys_diary('1659-01-01')
    entry.should.not.be nil
    found = Article.first(:slug => '1659-01-01')
    found.should.not.be nil
    found.should.be.kind_of Article
    found.should.be.kind_of Entry

    create_test_bookmark 'foo'
    bookmark = Bookmark.first(:slug => 'foo')
    bookmark.should.not.be nil
    bookmark.should.be.kind_of Bookmark
    bookmark.should.be.kind_of Entry

    Article.all.length.should.be 1
    Article.all.to_a.length.should.be 1
    Article.all.to_a.first.slug.should.be == '1659-01-01'

    Bookmark.all.length.should.be 1
    Bookmark.all.to_a.length.should.be 1
    Bookmark.all.to_a.first.slug.should.be == 'foo'

    Entry.all.length.should.be 2

    Article.first(:slug => 'foo').should.be nil
    Bookmark.first(:slug => '1659-01-01').should.be nil
  end

  it "finds an Article via Entry::first (STI)" do
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

  it "should not allow saving without a #slug, #title, and #filter" do
    Entry.new.save.should.not.be.truthful
    Entry.new(:slug  => 'bar').save.should.not.be.truthful
    Entry.new(:title => 'Foo').save.should.not.be.truthful
    Entry.new(:slug => 'foo', :title => 'Foo').save.should.be.truthful
  end

  it "assumes a default text #filter" do
    entry = Entry.new
    entry.filter.should.equal 'markdown'
  end

  it "accepts a variety of true/false values to #published=" do
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

  it 'coerces #published to a boolean out of the database' do
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

  it 'updates created_at and updated_at when publishing' do
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

  it 'finds only published entries with ::published' do
    (1..10).each do |i|
      bm = create_test_bookmark("test#{i}")
      bm.publish! if 0 == (i % 2)
    end
    Bookmark.published.length.should.be 5
    Bookmark.published.to_a.length.should.be 5
    Bookmark.published.each { |bm| bm.published?.should.be true }
    Entry.published.length.should.be 5
    Entry.published.to_a.length.should.be 5
    Entry.published.each { |bm|
      bm.published?.should.be(true) && bm.should.be.kind_of(Bookmark) }
    Article.published.should.be.empty
  end

  it 'finds only draft entries with ::drafts' do
    (1..10).each do |i|
      bm = create_test_bookmark("test#{i}")
      bm.publish! if 0 == (i % 2)
    end
    Bookmark.drafts.length.should.be 5
    Bookmark.drafts.to_a.length.should.be 5
    Bookmark.drafts.each { |bm| bm.draft?.should.be true }
    Entry.drafts.length.should.be 5
    Entry.drafts.to_a.length.should.be 5
    Entry.drafts.each { |bm|
      bm.draft?.should.be(true) && bm.should.be.kind_of(Bookmark) }
    Article.drafts.should.be.empty
  end

  it 'finds most recent entry with ::latest' do
    time = Time.now
    last = nil
    (5..1).each do |i|
      entry = Entry.new(:slug => "test#{i}", :title => 'Test', :published => true)
      entry.created_at = (time - i)
      entry.save.should.be true
      last = entry
    end
    Entry.latest.should.equal last
  end

  it 'finds entries in year with ::circa' do
    e06 = Entry.create!(:slug => '06', :title => 'Sometime in 2006', :published => true)
    e06.created_at = Date.new(2006, 3, 25)
    e06.save.should.be true
    Entry.first(:slug => '06').created_at.to_date.should.be == Date.new(2006, 3, 25)

    e07 = Entry.create!(:slug => '07', :title => 'Sometime in 2007', :published => true)
    e07.created_at = Date.new(2007, 5, 13)
    e07.save.should.be true

    e08 = Entry.create!(:slug => '08', :title => 'Sometime in 2009', :published => true)
    e08.created_at = Date.new(2008, 9, 23)
    e08.save.should.be true

    Entry.circa(2007).length.should.be == 1
    Entry.circa(2007).should.be == [ e07 ]
  end

end


describe "Entry#tags association" do

  before(:each) { setup_database }
  after(:each)  { teardown_database }

  it 'can be used to tag new entries' do
    entry = Entry.new(:slug => 'test', :title => 'Test Tagging Entry')
    entry.should.be.new_record
    entry.tags << Tag.new(:name => 'foo')
    entry.tags << Tag.new(:name => 'bar')
    entry.tags << Tag.new(:name => 'baz')
    entry.tags.length.should.be 3
    entry.should.be.new_record
    entry.tags.each { |t| t.should.be.new_record }
    entry.save
    entry.should.not.be.new_record
    entry.tags.each { |t| t.should.not.be.new_record }
  end

  it 'can be used to tag saved entries' do
    entry = Entry.create(:slug => 'test', :title => 'Test Tagging Entry')
    entry.should.not.be.new_record
    entry.errors.should.be.empty
    entry.tags << Tag.new(:name => 'foo')
    entry.tags << Tag.new(:name => 'bar')
    entry.tags << Tag.new(:name => 'baz')
    entry.tags.length.should.be 3
    entry.tags.each { |t| t.should.be.new_record }
    entry.save
    entry.tags.each { |t| t.should.not.be.new_record }
  end

  it 'can be cleared' do
    entry = Entry.create(:slug => 'test', :title => 'Test Tagging Entry')
    entry.should.not.be.new_record
    entry.errors.should.be.empty
    %w[foo bar baz].each { |t| entry.tags << Tag.new(:name => t) }
    entry.save.should.be.truthful
    entry.tags.length.should.be 3
    entry.tags.should.respond_to :clear
    entry.tags.clear
    entry.tags.length.should.be 0
    # it doesn't persist the clear until saved ... watch when we reload:
    entry = Entry.first(:slug => 'test')
    entry.tags.length.should.be 3
    # clear it again and save
    entry.tags.clear
    entry.save
    entry = Entry.first(:slug => 'test')
    entry.tags.should.be.empty
  end

end

describe 'Entry#tag_names attribute' do

  before(:each) { setup_database }
  after(:each)  { teardown_database }

  it 'takes an array of strings' do
    entry = Entry.create(:slug => 'test', :title => 'Test Tagging Entry')
    entry.tag_names = ['foo','bar','baz']
    entry.save
    entry.errors.should.be.empty
    entry.tags.length.should.be 3
    entry.tag_names.sort.should.be == ['bar','baz','foo']
  end

  it 'takes a space separated string' do
    entry = Entry.create(:slug => 'test', :title => 'Test Tagging Entry')
    entry.tag_names = 'foo bar baz'
    entry.save
    entry.errors.should.be.empty
    entry.tags.length.should.be 3
    entry.tag_names.sort.should.be == ['bar','baz','foo']
  end

  it 'takes a comma separated string' do
    entry = Entry.create(:slug => 'test', :title => 'Test Tagging Entry')
    entry.tag_names = 'foo, bar, baz'
    entry.save
    entry.errors.should.be.empty
    entry.tags.length.should.be 3
    entry.tag_names.sort.should.be == ['bar','baz','foo']
  end

  it 'automatically removes duplicate tags' do
    entry = Entry.create(:slug => 'test', :title => 'Test Tagging Entry')
    entry.tag_names = %w[foo bar baz bar foo]
    entry.save
    entry.errors.should.be.empty
    entry.tags.length.should.be 3
    entry.tag_names.sort.should.be == ['bar','baz','foo']
  end

end
