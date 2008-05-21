#!/usr/bin/env ruby

root_dir = File.dirname(__FILE__)
$:.unshift "#{root_dir}/sinatra/lib"
$:.unshift "#{root_dir}/lib"
$:.unshift root_dir

require 'rubygems'
require 'net/http'
require 'haml'
require 'bluecloth'
require 'rubypants'
require 'html5/html5parser'
require 'html5/sanitizer'
require 'sinatra'
require 'rack_cacher'
require 'akismet'
require 'data_mapper'
require 'ostruct'
require 'yaml'

configure do

  Weblog = OpenStruct.new(
    :url      => 'http://localhost:4567',

    :username => 'admin',
    :password => nil,

    :author => 'Fred Flinstone',
    :title => 'My Weblog',
    :writings => 'Writings',
    :linkings => 'Linkings',
    :url_regex => /^http:\/\/(mydomain\.com)/ 
  )

  def Weblog.configure
    yield self
  end

  def environment
    Sinatra.application.options.env.to_sym
  end

  def production?
    environment == :production
  end

  def development?
    environment == :development
  end

  class DataMapper::Database

    class Logger < ::Logger
      def format_message(sev, date, message, progname)
        message = progname if message.blank?
        "#{message}\n"
      end
    end

    def create_logger
      logger = Logger.new(STDERR)
      logger.level = Logger::DEBUG if development?
      logger.datetime_format = ''
      logger
    end

    def self.create!(options={})
      [ Entry, Comment, Tag, EntryTags ].each do |model|
        model.table.create! options[:force]
      end
    end

    def self.drop!
      [ Entry, Comment, Tag, EntryTags ].each do |model|
        model.table.drop!
      end
    end

  end

  Database = DataMapper::Database

  class Entry
  end

  class Bookmark < Entry
    @delicious = nil
    def self.configure
      require 'delicious'
      @delicious ||= Delicious::Synchronization.new
      yield @delicious if block_given?
      @delicious
    end
  end

  config_file = "#{root_dir}/#{environment}.conf"
  load config_file

end


class Entry
  include DataMapper::Persistence

  property :slug, :string, :size => 255, :nullable => false
  property :type, :class, :nullable => false
  property :published, :boolean, :default => false
  property :title, :string, :size => 255, :nullable => false
  property :summary, :text, :lazy => false
  property :filter, :string, :size => 20, :default => 'markdown'
  property :url, :string, :size => 255
  property :created_at, :datetime, :nullable => false
  property :updated_at, :datetime, :nullable => false
  property :body, :text

  index [ :slug ], :unique => true
  index [ :type ]
  index [ :created_at ]

  validates_presence_of :title, :slug, :filter

  has_many :comments,
    :spam.not => true,
    :order => 'created_at ASC'

  has_and_belongs_to_many :tags

  def stem
    "writings/#{slug}"
  end

  def permalink
    "#{Weblog.url}/#{stem}"
  end

  def domain
    if url && url =~ /https?:\/\/([^\/]+)/
      $1.strip.sub(/^www\./, '')
    end
  end

  def created_at
    @created_at ||= Time.now
  end

  def filter
    @filter ||= 'markdown'
  end

  def published?
    [1,true].include?(published)
  end

  def draft?
    ! published?
  end

  def body?
    ! body.empty?
  end

  def tag_names=(value)
    tags.clear
    tag_names =
      if value.respond_to?(:to_ary)
        value.to_ary
      elsif value.respond_to?(:to_str)
        value.gsub(/[\s,]+/, ' ').split(' ').uniq
      end
    tag_names.each do |tag_name|
      tag = Tag.find_or_create(:name => tag_name)
      tags << tag
    end
  end

  def tag_names
    tags.collect { |t| t.name }
  end

  def publish=(value)
    value = ['Publish', '1', 'true', 'yes'].include?(value.to_s)
    self.created_at = self.updated_at = Time.now if value && draft?
    self.published = value
  end

  # This shouldn't be necessary but DM isn't adding the type condition.
  def self.all(options={})
    return super if self == Entry
    options = { :type => ([self] + self::subclasses.to_a) }.
      merge(options)
    super(options)
  end

  def self.published(options={})
    options = { :order => 'created_at DESC', :published => true }.
      merge(options)
    all(options)
  end

  def self.published_circa(year, options={})
    options = {
      :created_at.gte => Date.new(year, 1, 1),
      :created_at.lt => Date.new(year + 1, 1, 1),
      :order => 'created_at ASC'
    }.merge(options)
    published(options)
  end

  def self.drafts(options={})
    options = { :order => 'created_at DESC', :published => false }.
      merge(options)
    all(options)
  end

  def self.tagged(tag, options={})
    if tag = Tag.first(:name => tag)
      tag.entries
    else
      []
    end
  end

end

class Article < Entry
end

class Bookmark < Entry

  def stem
    "linkings/#{slug}"
  end

  def filter
    'markdown'
  end

  # The Time of the most recently updated Bookmark in UTC.
  def self.last_updated_at
    latest = first(:order => 'created_at DESC', :type => 'Bookmark')
    # NOTE: we take DateTime through an ISO8601 string on purpose to maintain
    # timezone info. DateTime#to_time does not work properly.
    Time.iso8601(latest.created_at.strftime("%FT%T%Z"))
  end

  def self.synchronize(options={})
    delicious = self.delicious.dup
    options.each { |key,val| delicious.send("#{key}=", val) }
    count = 0
    delicious.synchronize :since => last_updated_at do |source|
      next if source[:href] =~ Weblog.url_regex
      next unless source[:shared]
      bookmark = find_or_create(:slug => source[:hash])
      bookmark.attributes = {
        :url        => source[:href],
        :title      => source[:description],
        :summary    => source[:extended],
        :body       => source[:extended],
        :filter     => 'text',
        :created_at => source[:time].getlocal,
        :updated_at => source[:time].getlocal,
        :published  => 1
      }
      bookmark.tag_names = source[:tags]
      bookmark.save
      count += 1
    end
    count
  end

end


class Tag
  include DataMapper::Persistence

  property :name, :string, :nullable => false
  property :created_at, :datetime, :nullable => false
  property :updated_at, :datetime, :nullable => false

  index [ :name ], :unique => true

  has_and_belongs_to_many :entries,
    :conditions => { :published => true },
    :order => "(entries.type = 'Bookmark') ASC, entries.created_at DESC"

  def to_s
    name
  end
end

class EntryTags
  include DataMapper::Persistence

  set_table_name 'entries_tags'
  belongs_to :entry
  belongs_to :tag
  index [ :entry_id ]
  index [ :tag_id ]
end

class Comment
  include DataMapper::Persistence

  property :author, :string, :size => 80
  property :ip, :string, :size => 50
  property :url, :string, :size => 255
  property :body, :text
  property :created_at, :datetime, :nullable => false
  property :referrer, :string, :size => 255
  property :user_agent, :string, :size => 255
  property :checked, :boolean, :default => false
  property :spam, :boolean, :default => false

  belongs_to :entry

  index [ :entry_id ]
  index [ :spam ]
  index [ :created_at ]

  validates_presence_of :body
  validates_presence_of :entry_id

  before_create do |comment|
    comment.check
    true
  end

  def self.ham(options={})
    all({:spam.not => true, :order => 'created_at DESC'}.merge(options))
  end

  def self.spam(options={})
    all({:spam => true, :order => 'created_at DESC'}.merge(options))
  end

  def excerpt(length=65)
    body.to_s.gsub(/[\s\r\n]+/, ' ')[0..65] + " ..."
  end

  def body_with_links
    body.to_s.
      gsub(/(^|[\s\t])(www\.\S+)/, '\1<http://\2>').
      gsub(/(?:^|[^\]])\((https?:\/\/[^)]+)\)/, '<\1>').
      gsub(/(^|[\s\t])(https?:\/\/\S+)/, '\1<\2>').
      gsub(/^(\s*)(#\d+)/) { [$1, "\\", $2].join }
  end

  def spam?
    spam
  end

  def ham?
    ! spam?
  end

  def check
    @checked = true
    @spam = check_comment
  rescue ::Net::HTTPError => boom
    logger.error "An error occured while connecting to Akismet: #{boom.to_s}"
    @checked = false
  end

  def check!
    check
    save!
  end

  def spam!
    @spam = true
    submit_spam
    save!
  end

  def url
    if @url.to_s.strip.blank?
      nil
    else
      @url.strip
    end
  end

  def author_link
    case url
    when nil                         then nil
    when /^mailto:.*@/, /^https?:.*/ then url
    when /@/                         then "mailto:#{url}"
    else                                  "http://#{url}"
    end
  end

  def author_link?
    !author_link.nil?
  end

  def author
    if @author.blank?
      'Anonymous Coward'
    else
      @author
    end
  end

private

  def akismet_params(others={})
    { :user_ip            => ip,
      :user_agent         => user_agent,
      :referrer           => referrer,
      :permalink          => entry.permalink,
      :comment_type       => 'comment',
      :comment_author     => author,
      :comment_author_url => url,
      :comment_content    => body }.merge(others)
  end

  def check_comment(params=akismet_params)
    if production?
      self.class.akismet.check_comment(params)
    else
      false
    end
  end

  def submit_spam(params=akismet_params)
    self.class.akismet.submit_spam(params)
  end

  # Wipe out the akismet singleton every 10 minutes due to suspected leaks.
  def self.akismet
    @akismet = Akismet::new('d4d4c1ed9a0e', Weblog.url) if @akismet.nil? || (akismet_age > 600)
    @last_akismet_access = Time.now
    @akismet
  end

  def self.akismet_age
    Time.now - @last_akismet_access
  end

end


# Setup Rack middleware
use Rack::Lint if development?
use Rack::Cacher

helpers do
  include Rack::Utils

  def h(string)
    escape_html(string)
  end

  def markdown_filter(text)
    html = BlueCloth.new(text || '').to_html
    html.chomp!
    html.chomp!('<hr/>')
    html.chomp!
    RubyPants.new(html).to_html
  rescue => boom
    "<p><strong>Boom!</strong></p><pre>#{h(boom.to_s)}</pre>"
  end

  def text_filter(text)
    "<p>#{escape_html(text || '')}</p>"
  end

  def html_filter(text)
    text || ''
  end

  def content_filter(text, filter=:markdown)
    send("#{filter}_filter", text)
  end

  # Sanitize HTML using html5lib.
  def sanitize(html)
    HTML5::HTMLParser.
      parse_fragment(html, :tokenizer => HTML5::HTMLSanitizer, :encoding => 'utf-8').
      to_s
  end

  # Convert hash to HTML attribute string.
  def attributes(*attrs)
    return '' if attrs.empty?
    attrs.inject({}) { |attrs,hash| attrs.merge(hash) }.
      reject { |k,v| v.nil? }.
      collect { |k,v| "#{k}='#{h(v)}'" }.
      join(' ')
  end

  # When content is nil, tag is non-closing (<foo>); when content is 
  # an empty string, tag is self-closed (<foo />); all other values
  # create a normal content tag (<foo>BAR</foo>). All attribute values
  # are html escaped. The content value is NOT escaped.
  def tag(name, content, *attrs)
  [
    "<#{name}",
    (" #{attributes(*attrs)}" if attrs.any?),
    (case content
     when nil then '>'
     else ">#{content}</#{name}>"
     end)
  ].compact.join
  end

  def feed(href, title)
    tag :link, nil,
      :rel => 'alternate', 
      :type => 'application/atom+xml', 
      :title => title,
      :href => href
  end

  def css(href, media='all')
    href = "/stylesheets/#{href}.css" unless href =~ /\.css$/
    tag :link, nil,
      :rel => 'stylesheet',
      :type => 'text/css',
      :href => href,
      :media => media
  end

  # When src is a single word, assume it is an external resource and 
  # use `<script src=`; otherwise, embed script in tag.
  def script(src)
    if src =~ /\s/
      %(<script type='text/javascript'>#{src}</script>)
    else
      src = "/js/#{src}.js" unless src =~ /\.js$/
      %(<script type='text/javascript' src='#{src}'></script>)
    end
  end

  def href(text, url, *attrs)
    tag :a, h(text), { :href => url }, *attrs
  end

  def root_url(*args)
    [ Weblog.url, *args ].compact.join("/")
  end

  def entry_url(entry)
    entry.url || root_url('writings', entry.slug)
  end

  def entry_ref(entry, text=entry.title, *attrs)
    href(text, entry_url(entry), *attrs)
  end

  def draft_url(entry)
    root_url('drafts', entry.slug)
  end

  def draft_ref(entry, text, *attrs)
    href(text, draft_url(entry), *attrs)
  end

  def topic_url(tag)
    root_url('topics', tag.to_s)
  end

  def topic_ref(tag)
    href(tag.to_s, topic_url(tag))
  end

  def input(type, name, value=nil, *attrs)
    tag :input, nil, 
      { :id => name, :name => name, :type => type.to_s, :value => value }, 
      *attrs
  end

  def textbox(name, value=nil)
    input :text, name, value
  end

  def textarea(name, value, *attrs)
    tag :textarea, h(value || ''), { :name => name, :id => name }, *attrs
  end

  def selectbox(name, value, options)
    options.inject("<select name='#{name}' id='#{name}'>") { |m,(k,v)| 
      m << "<option value='#{h(k)}'#{v == value && ' selected' || ''}>#{h(v)}</option>"
    } << "</select>"
  end

end

# Resources =================================================================

get '/' do
  redirect '/', 301 if params[:page]
  @title = Weblog.title
  @entries = Entry.published(:limit => 50)
  haml :home
end

get '/writings/' do
  @title = Weblog.writings
  @entries = Article.published
  haml :home
end

get '/linkings/' do
  @title = Weblog.linkings
  @entries = Bookmark.published(:limit => 100)
  haml :home
end

get '/circa/:year/' do
  @title = "#{Weblog.author} circa #{params[:year].to_i}"
  @entries = Entry.published_circa(params[:year].to_i)
  haml :home
end

get '/topics/:tag' do
  @title = "Regarding: '#{h(params[:tag].to_s.upcase)}'"
  @entries = Entry.tagged(params[:tag])
  @entries.reject! { |e| e.draft? }
  @entries.sort! do |b,a|
    if a.is_a?(Bookmark) && !b.is_a?(Bookmark)
      -1
    elsif b.is_a?(Bookmark) && !a.is_a?(Bookmark)
      1
    else
      a.created_at <=> b.created_at
    end
  end
  haml :home
end

get '/writings/:slug' do
  @entry = Article.first(:slug => params[:slug])
  raise Sinatra::NotFound unless @entry
  require_administrative_privileges if @entry.draft?
  @title = @entry.title
  @comments = @entry.comments
  haml :entry
end

get '/drafts/' do
  require_administrative_privileges
  @entries = Entry.drafts
  haml :home
end

get '/drafts/new' do
  require_administrative_privileges
  @title = 'New Draft'
  @entry = Article.new(
    :created_at => Time.now,
    :updated_at => Time.now,
    :filter => 'markdown'
  )
  haml :draft
end

post '/drafts/' do
  require_administrative_privileges
  @entry =
    if params[:id].nil? || params[:id].empty?
      Article.new
    else
      Entry[params[:id].to_i]
    end
  @entry.tag_names = params[:tag_names]
  @entry.publish = params[:publish] if params[:publish]
  @entry.attributes = params.to_hash
  @entry.save
  purge_cache "**/index.html", "**/feed.atom", "writings/#{@entry.slug}.*",
    "topics/*"
  redirect entry_url(@entry)
end

get '/drafts/:slug' do
  require_administrative_privileges
  @entry = Entry.first(:slug => params[:slug])
  raise Sinatra::NotFound unless @entry
  @title = @entry.title
  haml :draft
end

# Feeds ======================================================================

mime :atom, 'application/atom+xml'

get '/feed' do
  @title = Weblog.writings
  @entries = Article.published(:limit => 10)
  content_type :atom, :charset => 'utf-8'
  builder :feed, :layout => :none
end

get '/linkings/feed' do
  @title = Weblog.linkings
  @entries = Bookmark.published(:limit => 30)
  content_type :atom, :charset => 'utf-8'
  builder :feed, :layout => :none
end

get '/comments/feed' do
  @title = "Recent Comments"
  @comments = Comment.ham(:limit => 25)
  content_type :atom, :charset => 'utf-8'
  builder :comment_feed, :layout => :none
end

# Comments ===================================================================

get '/comments/' do
  @title = 'Recent Discussion'
  @comments = Comment.ham(:limit => 50)
  haml :comments
end

get '/spam/' do
  require_administrative_privileges
  @title = 'Spam'
  @comments = Comment.spam(:limit => 100)
  haml :comments
end

delete '/comments/:id' do
  require_administrative_privileges
  comment = Comment[params[:id].to_i]
  raise Sinatra::NotFound if comment.nil?
  purge_cache "writings/#{comment.entry.slug}.*", "/comments/*"
  comment.destroy!
  ''
end

put '/comments/:id' do
  require_administrative_privileges
  bad_request! if request.media_type != 'text/plain'
  comment = Comment[params[:id].to_i]
  raise Sinatra::NotFound if comment.nil?
  comment.body = request.body.read
  comment.save
  status 204
  purge_cache "writings/#{comment.entry.slug}.*", "comments/*"
  ''
end

get '/comments/:id' do
  comment = Comment[params[:id].to_i]
  raise Sinatra::NotFound if comment.nil?
  content_filter(comment.body_with_links, :markdown)
end

post '/writings/:slug/comment' do
  entry = Entry.first(:slug => params[:slug])
  raise Sinatra::NotFound if entry.nil?
  attributes = {
    :referrer    => request.referrer,
    :user_agent  => request.user_agent,
    :ip          => request.remote_ip, 
    :body        => params[:body],
    :url         => params[:url],
    :author      => params[:author],
    :spam        => false
  }
  comment = entry.comments.create(attributes)
  if comment.spam?
    status 403
    haml :rickroll
  else
    purge_cache "writings/#{entry.slug}.*", "comments/*"
    redirect entry_url(entry) + "#comment-#{comment.id}"
  end
end

# Authentication and Authorization ===========================================

helpers do

  def auth
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
  end

  def unauthorized!(realm=Weblog.realm)
    header 'WWW-Authenticate' => %(Basic realm="#{realm}")
    throw :halt, [ 401, 'Authorization Required' ]
  end

  def bad_request!
    throw :halt, [ 400, 'Bad Request' ]
  end

  def authorized?
    request.env['REMOTE_USER']
  end

  def authorize
    credentials = [ Weblog.username, Weblog.password ]
    if auth.provided? && credentials == auth.credentials
      request.env['weblog.admin'] = true
      request.env['REMOTE_USER'] = auth.username
    end
  end

  def require_administrative_privileges
    return if authorized?
    unauthorized! unless auth.provided?
    bad_request! unless auth.basic?
    unauthorized! unless authorize
  end

  def admin?
    authorized? || authorize
  end

end

get '/identify' do
  require_administrative_privileges
  redirect(params[:dest] || '/')
end


# Rack Extensions ============================================================

module Rack
  class Request
    def remote_ip
      @env['HTTP_X_FORWARDED_FOR'] || @env['HTTP_CLIENT_IP'] || @env['REMOTE_ADDR']
    end
  end
end


require 'time'
class DateTime
  def iso8601
    to_time.iso8601
  end
end

# don't run server unless invoked directly
set_option :run, false unless $0 == __FILE__
