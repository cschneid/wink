require 'time'

module Delicious

  class Synchronization

    # The del.icio.us username.
    attr_accessor :user

    # The del.icio.us password
    attr_accessor :password

    # Path to file to use as a cache of all bookmarks. This is used primarily
    # for testing.
    attr_accessor :cache_path

    def initialize(options={})
      @user = options[:user]
      @password = options[:password]
      @cache_path = options[:cache_path] || options[:cache]
      @last_updated_at = nil
      yield self if block_given?
    end

    # Open the bookmarks and return an REXML::Document. If the cache option is
    # provided, the document is loaded from the localpath specified.
    def open
      require 'rexml/document'
      xml =
        if cache_path && File.exist?(cache_path)
          File.read(cache_path)
        else
          request(:all)
        end
      File.open(cache_path, 'wb') { |io| io.write(xml) } if cache_path
      REXML::Document.new(xml)
    end

    # The Time of the most recently updated bookmark on del.icio.us.
    def last_updated_at
      if cache_path
        @last_updated_at ||= remote_last_updated_at
      else
        remote_last_updated_at
      end
    end

    # Determine if any bookmarks have been updated since the time
    # specified.
    def updated_since?(time)
      time < last_updated_at
    end

    # Yield each bookmark to the block that requires synchronization. The :since
    # option may be specified to indicate the time of the most recently updated
    # bookmark. Only bookmarks whose time is more recent than the time specified
    # are yielded.
    def synchronize(options={})
      if since = options[:since]
        since.utc
        return false unless updated_since?(since)
      else
        since = Time.at(0)
        since.utc
      end
      open.elements.each('posts/post') do |el|
        attributes = el.attributes
        time = Time.iso8601(attributes['time'])
        next if time <= since
        yield :href    => attributes['href'],
          :hash        => attributes['hash'],
          :description => attributes['description'],
          :extended    => attributes['extended'],
          :time        => time,
          :shared      => (attributes['shared'] != 'no'),
          :tags        => attributes['tag'].split(' ')
      end
    end

  private

    def remote_last_updated_at
      require 'rexml/document'
      doc = REXML::Document.new(request('update'))
      Time.iso8601(doc.root.attributes['time'])
    end

    def request(method)
      require 'net/https'
      http = Net::HTTP.new('api.del.icio.us', 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      res = http.start do |http|
        req = Net::HTTP::Get.new("/v1/posts/#{method}", 'User-Agent' => 'bookmark.rb v1.0')
        req.basic_auth(user, password)
        http.request(req)
      end
      res.value
      res.body
    end

  end

end


if $0 == __FILE__

  require 'test/unit/assertions'
  include Test::Unit::Assertions

  delicious =
    Delicious::Synchronization.new :user => 'test',
      :password => 'test',
      :cache => 'bookmarks.xml'

  assert_not_nil delicious.user
  assert_not_nil delicious.password
  assert_not_nil delicious.cache_path

  updated = Time.iso8601("2008-04-03T12:57:15Z")

  assert delicious.last_updated_at.utc?, "should be UTC"
  assert_equal updated, delicious.last_updated_at

  delicious.synchronize :since => updated do |bookmark|
    flunk "should not yield when up to date"
  end

  count = 0
  delicious.synchronize :since => Time.iso8601("2008-04-02T13:33:50Z") do |bookmark|
    count += 1
    [ :shared, :tags, :description, :extended, :time, :href, :hash ].each do |key|
      assert_not_nil bookmark[key], "#{key.inspect} should be set"
    end
    assert bookmark[:tags].length > 0, "should be some tags"
  end
  assert_equal 5, count

end

