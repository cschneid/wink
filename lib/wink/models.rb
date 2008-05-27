require 'wink/akismet'

class Entry
  include DataMapper::Persistence

  property :id, :integer, :serial => true
  property :slug, :string, :size => 255, :nullable => false, :index => :unique
  property :type, :class, :nullable => false, :index => true
  property :published, :boolean, :default => false
  property :title, :string, :size => 255, :nullable => false
  property :summary, :text, :lazy => false
  property :filter, :string, :size => 20, :default => 'markdown'
  property :url, :string, :size => 255
  property :created_at, :datetime, :nullable => false, :index => true
  property :updated_at, :datetime, :nullable => false
  property :body, :text

  validates_presence_of :title, :slug, :filter

  has_many :comments,
    :spam.not => true,
    :order => 'created_at ASC'

  has_and_belongs_to_many :tags,
    :join_table => 'taggings'

  def initialize(attributes={})
    @created_at = DateTime.now
    @filter = 'markdown'
    super
  end

  def stem
    "writings/#{slug}"
  end

  def permalink
    "#{Wink.url}/#{stem}"
  end

  def domain
    if url && url =~ /https?:\/\/([^\/]+)/
      $1.strip.sub(/^www\./, '')
    end
  end

  def created_at=(value)
    value = value.to_datetime if value.respond_to?(:to_datetime)
    @created_at = value
  end

  def updated_at=(value)
    value = value.to_datetime if value.respond_to?(:to_datetime)
    @updated_at = value
  end

  def published?
    !! published
  end

  def published=(value)
    value = ! ['false', 'no', '0', ''].include?(value.to_s)
    self.created_at = self.updated_at = DateTime.now if value && draft?
    @published = value
  end
  alias publish= published=

  def draft?
    ! published
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

  def self.all(options={})
    return super if self == Entry
    # XXX This shouldn't be necessary but DM isn't adding the type condition.
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

  # Synchronize bookmarks with del.icio.us. The :delicious configuration option
  # must be set to a two-tuple of the form: ['username','password']. Returns the
  # number of bookmarks synchronized when successful or nil if del.icio.us
  # synchronization is disabled.
  def self.synchronize(options={})
    return nil if Wink[:delicious].nil?
    require 'wink/delicious'
    delicious = Wink::Delicious.new(*Wink[:delicious])
    options.each { |key,val| delicious.send("#{key}=", val) }
    count = 0
    delicious.synchronize :since => last_updated_at do |source|
      next if Wink[:url_regex] && source[:href] =~ Wink[:url_regex]
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

  property :id, :integer, :serial => true
  property :name, :string, :nullable => false, :index => :unique
  property :created_at, :datetime, :nullable => false
  property :updated_at, :datetime, :nullable => false

  has_and_belongs_to_many :entries,
    :conditions => { :published => true },
    :order => "(entries.type = 'Bookmark') ASC, entries.created_at DESC",
    :join_table => 'taggings'

  def to_s
    name
  end
end


class Tagging
  include DataMapper::Persistence

  belongs_to :entry
  belongs_to :tag
  index [:entry_id]
  index [:tag_id]
end


class Comment
  include DataMapper::Persistence

  property :id, :integer, :serial => true
  property :author, :string, :size => 80
  property :ip, :string, :size => 50
  property :url, :string, :size => 255
  property :body, :text, :nullable => false
  property :created_at, :datetime, :nullable => false, :index => true
  property :referrer, :string, :size => 255
  property :user_agent, :string, :size => 255
  property :checked, :boolean, :default => false
  property :spam, :boolean, :default => false, :index => true

  belongs_to :entry
  index [ :entry_id ]

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

  # Has the current comment been marked as spam?
  def spam?
    spam
  end

  # Opposite of #spam? -- true when the comment has not been marked as
  # spam.
  def ham?
    ! spam?
  end

  # Check the comment with Akismet. The spam attribute is updated to reflect
  # whether the spam was detected or not.
  def check
    @checked = true
    @spam = akismet(:check) || false
  rescue => boom
    logger.error "An error occured while connecting to Akismet: #{boom.to_s}"
    @checked = false
  end

  # Check the comment with Akismet and immediately save the comment.
  def check!
    check
    save!
  end

  # Mark this comment as spam and immediately save the comment. If Akismet is
  # enabled, the comment is submitted as spam.
  def spam!
    @spam = true
    akismet :spam!
    save!
  end

private

  # Should comments be checked with Akismet before saved?
  def akismet?
    Wink[:akismet] && production?
  end

  # Send an Akismet request with parameters from the receiver's model. Return
  # nil when Akismet is not enabled.
  def akismet(method, extra={})
    akismet_connection.__send__(method, akismet_params(extra)) if akismet?
  end

  # Build a Hash of Akismet parameters based on the properties of the receiver.
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

  # The Wink::Akismet instance used for checking comments.
  def akismet_connection
    @akismet_connection ||= Akismet::new(Wink[:akismet], Wink[:url])
  end

end
