require 'sinatra'
require 'wink/core_extensions'
require 'wink/schema'

# Tell Sinatra to not automatically start a server.
set :run, false

unless reloading?

  # The site's root URL. Note: the trailing slash should be 
  # omitted when setting this option.
  set :url, 'http://localhost:4567'

  # A regular expression that matches URLs to your site's content. Used
  # to detect bookmarks and external content referencing the current site.
  set :url_regex, /http\:/

  # The full name of the site's author.
  set :author, 'Anonymous Coward'

  # The administrator username. You will be prompted to authenticate with
  # this username before modifying entries and comments or providing other
  # administrative activities. Default: "admin".
  set :username, 'admin'

  # The administrator password (see #username). The password is +nil+ by
  # default, disabling administrative access; you must set the password
  # explicitly.
  set :password, nil

  # The site's Akismet key, if spam detection should be performed.
  set :akismet_key, nil

  # The URL of the site as registered with Akismet. Defaults to the
  # +url+ option.
  set :akismet_url, nil

  # Boolean specifying whether Akismet checks should be performed in all
  # environments. Default is to check w/ Akismet only when in production
  # environment.
  set :akismet_always, false

  # A del.icio.us username/password as a two-tuple: ['username', 'password'].
  # When set, del.icio.us bookmark synchronization may be performed by calling
  # Bookmark.synchronize!
  set :delicious, nil

  # Where to write log messages.
  set :log_stream, STDERR

  # The site's title. Defaults to the author's name.
  set :title, nil

  # Title of area that lists Article entries.
  set :writings, 'Writings'

  # Title of area that lists Bookmark entries.
  set :linkings, 'Linkings'

  # Start date for archives + copyright notice.
  set :begin_date, Date.today.year

  # List of filters to apply to comments.
  set :comment_filters, [:markdown, :sanitize]

  # URL mappings for various sections of the site
  set :writings_url, "/writings/"
  set :linkings_url, "/linkings/"
  set :archive_url , "/circa/"
  set :tag_url     , "/topics/"
  set :drafts_url  , "/drafts/"
end


module Wink
  extend self

  VERSION = '0.2'

  # An OpenStruct with all application options.
  def options
    Sinatra.application.options
  end

  # Get an option value.
  def [](option_name)
    options.send(option_name)
  end

  # Set an option value.
  def []=(option_name, value)
    options.send("#{option_name}=", value)
  end

  # Respond to any option attributes defined on the underlying #options
  # object and also to all setter messages.
  def respond_to?(name, include_private=false)
    super ||
      options.respond_to?(name, include_private) ||
      name.to_s[-1] == ?=
  end

  # Delegate all messages to the underlying #options object.
  def method_missing(name, *args, &block)
    options.__send__(name, *args, &block)
  end

  private :method_missing


  # Options ====================================================================

  def akismet_url
    self[:url]
  end


  # Configuration ==============================================================

  # Load configuration from the file specified and/or by executing the block. If
  # both a file and block are given, the config file is loaded first and then
  # the block is executed.
  #
  # Database configuration must be in place once the config file and block are
  # processed.
  def configure(file=nil)
    Kernel::load(file) if file
    yield options if block_given?
    require 'wink/models'
    self
  end

  # Load configuration from the file and/or block as specified in Wink#configure
  # and setup Sinatra to start a server instance.
  def run!(config_file=nil, &block)
    configure(config_file, &block)
    require 'wink/web'
    Sinatra.application.options.run = true
  end

  # Rackup compatible constructor. Use in Rackup files as follows:
  #
  #   require 'wink'
  #   run Wink do |config|
  #     config.env = :production
  #     config.url = 'http://example.com'
  #   end
  #
  # If neither a config_file or a block is given, load the default
  # config file: 'wink.conf'.
  def new(config_file=nil, &block)
    config_file ||= 'wink.conf' unless block_given?
    configure(config_file, &block)
    require 'wink/web'
    Sinatra.application
  end

end
