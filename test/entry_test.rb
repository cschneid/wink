require File.dirname(__FILE__) + "/help"
require 'fixtures'

context 'Entry' do

  setup    { setup_database }
  teardown { teardown_database }

  def create_simple_article
    entry = create_article_from_pepys_diary('1659-01-01')
    entry.should.not.be nil
    entry
  end

  specify 'should find none when no entries present' do
    Entry.all.length.should.equal 0
  end

  specify "should be able to create simple article" do
    entry = create_simple_article
    entry.tags.should.be.empty
    entry.should.respond_to :tag_names
    entry.tag_names.should.be.empty
    entry.published.should.not.be.truthful
    entry.body.should.equal read_file_from_pepys_diary('1659-01-01')
    entry.updated_at.should.not.be nil
    entry.updated_at.should.be.kind_of Time
    entry.created_at.should.not.be nil
    entry.created_at.should.be.kind_of Time
  end

  specify "should be able to find Article via Entry (STI)" do
    entry = create_simple_article
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

end
