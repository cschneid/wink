require File.dirname(__FILE__) + "/help"
require 'fixtures'

describe 'Comment' do

  before(:each) do
    setup_database
    @entry = Entry.create! :slug => 'comment-test', :title => 'Comment Test'
  end

  after(:each)  { teardown_database }

  it 'finds no comments when none exist' do
    Comment.all.length.should.be 0
  end

  it 'can be created with a body, url, and author name' do
    comment =
      Comment.create!(
        :body => 'Test Comment',
        :entry => @entry,
        :author => 'John Doe',
        :url => 'http://john.doe.com'
      )
    2.times do
      comment.body.should.be == 'Test Comment'
      comment.entry_id.should.be == @entry.id
      comment.entry.id.should.be == @entry.id
      comment.author.should.be == 'John Doe'
      comment.url.should.be == 'http://john.doe.com'
      comment = Comment.first
    end
  end

  it 'can be created with only a body' do
    comment = Comment.new(:body => 'Test Comment', :entry => @entry)

    comment.body.should.be == 'Test Comment'
    comment.entry_id.should.be == @entry.id
    comment.entry.id.should.be == @entry.id
    comment.author.should.be == 'Anonymous Coward'
    comment.url.should.be nil
    comment.author_link?.should.not.be.truthful
    comment.save.should.be.truthful

    comment = Comment.first
    comment.body.should.be == 'Test Comment'
    comment.entry_id.should.be == @entry.id
    comment.entry.id.should.be == @entry.id
    comment.author.should.be == 'Anonymous Coward'
    comment.url.should.be nil
    comment.author_link?.should.not.be.truthful
  end

  it 'finds only ham with ::ham' do
    Comment.should.respond_to :ham
    (1..10).each do |i|
      Comment.create! :body => "Test #{i}", 
        :entry => @entry,
        :checked => true,
        :spam => (0 == i % 2)
    end
    Comment.ham.length.should.be == 5
    Comment.ham.collect { |c| c.body } .
      sort.should.equal %w[1 3 5 7 9].map { |n| "Test #{n}" }
  end

  it 'finds only spam with ::spam' do
    Comment.should.respond_to :spam
    (1..10).each do |i|
      Comment.create! :body => "Test #{i}", 
        :entry => @entry,
        :checked => true,
        :spam => (0 == i % 2)
    end
    Comment.spam.length.should.be == 5
    Comment.spam.each { |c| c.should.be.spam }
    Comment.spam.collect { |c| c.body } .
      sort.should.equal %w[10 2 4 6 8].map { |n| "Test #{n}" }
  end

  it 'should not be checked or spam until saved' do
    Comment.new.should.not.be.checked
    Comment.new.should.not.be.spam
  end

  it 'defaults to ham if Akismet is not configured' do
    Comment.create! :entry => @entry, :body => 'Test Comment'
    Comment.first.should.be.ham
  end

  it 'is marked as spam and saved with #spam!' do
    comment = Comment.new(:entry => @entry, :body => 'Test Comment')
    comment.should.be.new_record
    comment.spam!
    comment.errors.should.be.empty
    comment.should.not.be.new_record
    comment.should.be.checked
    comment.should.be.spam
    comment = Comment.first
    comment.should.be.spam
    comment.should.not.be.ham
  end

  it 'is marked as ham and saved with #ham!' do
    comment = Comment.new(:entry => @entry, :body => 'Test Comment')
    comment.should.be.new_record
    comment.ham!
    comment.errors.should.be.empty
    comment.should.not.be.new_record
    comment.should.be.checked
    comment.should.be.ham
    comment = Comment.first
    comment.should.be.ham
    comment.should.not.be.spam
  end

end
