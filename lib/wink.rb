
require 'time'
class DateTime
  def iso8601
    to_time.iso8601
  end
end


require 'sinatra'

def environment
  Sinatra.application.options.env.to_sym
end

def reloading?
  Sinatra.application.reloading?
end

def production?
  environment == :production
end

def development?
  environment == :development
end

# don't run server by default when loaded as a library.
set_option :run, false


module Rack
  class Request
    def remote_ip
      @env['HTTP_X_FORWARDED_FOR'] || @env['HTTP_CLIENT_IP'] || @env['REMOTE_ADDR']
    end
  end
end


require 'ostruct'
Weblog = OpenStruct.new(
  :url          => 'http://localhost:4567',
  :author       => 'Fred Flinstone',
  :title        => 'My Weblog',
  :writings     => 'Writings',
  :linkings     => 'Linkings',
  :begin_date   => 2008,
  :url_regex    => /^http:\/\/(mydomain\.com)/,

  :username     => 'admin',
  :password     => nil,
  :akismet      => '',

  :log_stream   => STDERR
)

def Weblog.configure
  yield self
end


require 'data_mapper'
class DataMapper::Database

  class Logger < ::Logger
    def format_message(sev, date, message, progname)
      message = progname if message.blank?
      "#{message}\n"
    end
  end

  def create_logger
    logger = Logger.new(Weblog.log_stream)
    logger.level = Logger::DEBUG if development?
    logger.datetime_format = ''
    logger
  end

  # Acts exactly like Database#setup but runs exactly once. Multiple calls
  # to Database#setup result in multiple database connections being
  # established.
  def self.configure(options={})
    setup(options) unless reloading?
  end

  def self.create!(options={})
    [ Entry, Comment, Tag, Tagging ].each do |model|
      model.table.create! options[:force]
    end
  end

  def self.drop!
    [ Entry, Comment, Tag, Tagging ].each do |model|
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

load "#{Dir.getwd}/#{environment}.conf"

require 'wink/models'
require 'wink/web'

if reloading?
  load 'wink/models.rb'
  load 'wink/web.rb'
end
