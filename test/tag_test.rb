require File.dirname(__FILE__) + "/help"
require 'fixtures'

describe 'Tag' do

  before(:each) { setup_database }
  after(:each)  { teardown_database }

  it 'finds no tags when none exist' do
    Tag.all.length.should.equal 0
  end

  it "creates a Tag with ::new" do
    tag = Tag.new :name => 'test'
    tag.save.should.be.truthful
    tag = Tag.first(:name => 'test')
    tag.name.should.be == 'test'
  end

  it "responds to #to_s with tag name" do
    Tag.new(:name => 'test').to_s.should.be == 'test'
  end

  it "has #created_at and #updated_at attributes" do
    Tag.create!(:name => 'test')
    tag = Tag.first(:name => 'test')
    tag.created_at.should.not.be nil
    tag.updated_at.should.not.be nil
    tag.created_at.should.be.kind_of DateTime
    tag.updated_at.should.be.kind_of DateTime
  end

  it "does not allow duplicate tag names to be saved" do
    original = Tag.new(:name => 'test')
    original.save.should.be.truthful
    original.errors.should.be.empty
    duplicate = Tag.create(:name => 'test')
    duplicate.save.should.not.be.truthful
    duplicate.errors.should.not.be.empty
  end

  it "implements ::[] finder shortcut with Integer id" do
    tag = Tag.create!(:name => "test")
    Tag.should.respond_to :[]
    Tag[tag.id].should.be.kind_of Tag
    Tag[tag.id].id.should.be == tag.id
  end

  it "implements ::[] finder shortcut with String name" do
    (1..5).each { |i| Tag.create!(:name => "tag#{i}") }
    Tag.should.respond_to :[]
    Tag["tag2"].should.be.kind_of Tag
    Tag["tag2"].name.should.be == 'tag2'
  end

end
