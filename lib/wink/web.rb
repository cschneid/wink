require 'sinatra'
require 'haml'
require 'html5/html5parser'
require 'html5/sanitizer'

require 'wink'
require 'wink/markdown'
require 'wink/models'

module Wink::Helpers
  include Rack::Utils
  alias :h :escape_html

  # Sanitize HTML - removes potentially dangerous markup like <script> and
  # <object> tags.
  def sanitize(html)
    HTML5::HTMLParser.
      parse_fragment(html, :tokenizer => HTML5::HTMLSanitizer, :encoding => 'utf-8').
      to_s
  end

  # Convert text to HTML using Markdown (includes text smartification). Uses
  # RDiscount if available and falls back to BlueCloth.
  def markdown(text)
    return '' if text.nil? || text.empty?
    Wink::Markdown.new(text, :smart).to_html
  end

  # Make text "smart" by converting dumb puncuation characters to their
  # high-class equivalents.
  def smartify(text)
    return '' if text.nil? || text.empty?
    RubyPants.new(text).to_html
  end

  # Apply a list of content filters to text. Calls each helper method in
  # the order specified with the result of the previous operation. The following
  # are equivalent:
  #
  #   filter "Hello, World.", :markdown, :sanitize
  #   sanitize(markdown("Hello, World."))
  #
  def filter(text, *filters)
    filters.inject(text) do |text,method_name|
      send(method_name, text)
    end
  rescue => boom
    "<p><strong>Boom!</strong></p><pre>#{escape_html(boom.to_s)}</pre>"
  end

  def html(text)
    text || ''
  end

  # The comment's formatted body.
  def comment_body(comment=@comment)
    filter(comment.body, *Wink.comment_filters)
  end

  # The entry's formatted body.
  def entry_body(entry=@entry)
    filter(entry.body, entry.filter)
  end

  # The entry's formatted summary.
  def entry_summary(entry=@entry)
    filter(entry.summary, :markdown)
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
    href = "/css/#{href}.css" unless href =~ /\.css$/
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
    [ wink.url, *args ].compact.join("/")
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

  def wink
    Wink
  end

end


# Bring Wink::Helpers into Sinatra
helpers { include Wink::Helpers }


# Resources =================================================================

get '/' do
  redirect '/', 301 if params[:page]
  @title = wink.title
  @entries = Entry.published(:limit => 50)
  haml :home
end

get '/writings/' do
  @title = wink.writings
  @entries = Article.published
  haml :home
end

get '/linkings/' do
  @title = wink.linkings
  @entries = Bookmark.published(:limit => 100)
  haml :home
end

get '/circa/:year/' do
  @title = "#{wink.author} circa #{params[:year].to_i}"
  @entries = Entry.circa(params[:year].to_i)
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
    if params[:id].blank?
      Article.new
    else
      Entry[params[:id].to_i]
    end
  @entry.tag_names = params[:tag_names]
  @entry.attributes = params.to_hash
  @entry.save
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
  @title = wink.writings
  @entries = Article.published(:limit => 10)
  content_type :atom, :charset => 'utf-8'
  builder :feed, :layout => :none
end

get '/linkings/feed' do
  @title = wink.linkings
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
  ''
end

get '/comments/:id' do
  comment = Comment[params[:id].to_i]
  raise Sinatra::NotFound if comment.nil?
  comment_body(comment)
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
    redirect entry_url(entry) + "#comment-#{comment.id}"
  end
end

# Authentication and Authorization ===========================================

helpers do

  def auth
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
  end

  def unauthorized!(realm=wink.realm)
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
    credentials = [ wink.username, wink.password ]
    if auth.provided? && credentials == auth.credentials
      request.env['wink.admin'] = true
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
