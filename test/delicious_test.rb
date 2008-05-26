require File.dirname(__FILE__) + "/help"
require 'wink'

context 'wink/delicious' do

  specify 'should be requirable (and not have syntax errors)' do
    require 'wink/delicious'
  end

end

context 'Wink::Delicious' do

  specify 'should support synchronizing from cache file' do
    require 'wink/delicious'
    delicious = Wink::Delicious.new('test', 'test', :cache => 'bookmarks.xml')
    delicious.user.should.not.be.nil
    delicious.password.should.not.be.nil
    delicious.cache.should.not.be.nil

    # TODO: plumb in test bookmark file
    # assert delicious.last_updated_at.utc?, "should be UTC"
    # updated = Time.iso8601("2008-04-03T12:57:15Z")
    # assert_equal updated, delicious.last_updated_at
    # delicious.synchronize :since => updated do |bookmark|
    #   flunk "should not yield when up to date"
    # end
    # count = 0
    # delicious.synchronize :since => Time.iso8601("2008-04-02T13:33:50Z") do |bookmark|
    #   count += 1
    #   [ :shared, :tags, :description, :extended, :time, :href, :hash ].each do |key|
    #     assert_not_nil bookmark[key], "#{key.inspect} should be set"
    #   end
    #   assert bookmark[:tags].length > 0, "should be some tags"
    # end
    # assert_equal 5, count
  end

end
