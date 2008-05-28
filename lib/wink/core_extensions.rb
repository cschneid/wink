# Various extensions to core and library classes.

require 'date'
require 'time'

class DateTime #:nodoc:
  # ISO 8601 formatted time value. This is 
  alias_method :iso8601, :to_s

  def inspect
    "#<DateTime: #{to_s}>"
  end
end

class Date #:nodoc:
  def inspect
    "#<Date: #{to_s}>"
  end
end

require 'rack'

module Rack
  class Request

    # The IP address of the upstream-most client (e.g., the browser). This
    # is reliable even when the request is made through a reverse proxy or
    # other gateway.
    def remote_ip
      @env['HTTP_X_FORWARDED_FOR'] || @env['HTTP_CLIENT_IP'] || @env['REMOTE_ADDR']
    end

  end
end


require 'sinatra'

# The running environment as a Symbol; obtained from Sinatra's
# application options.
def environment
  Sinatra.application.options.env.to_sym
end

# Are we currently running under the production environment?
def production?
  environment == :production
end

# Are we currently running under the development environment?
def development?
  environment == :development
end

# Truthful when the application is in the process of being reloaded
# by Sinatra.
def reloading?
  Sinatra.application.reloading?
end

gem 'datamapper', '=0.2.5'
require 'data_mapper'

class DataMapper::Database #:nodoc:

  class Logger < ::Logger
    def format_message(sev, date, message, progname)
      message = progname if message.blank?
      "#{message}\n"
    end
  end

  def create_logger
    logger = Logger.new(Wink.log_stream)
    logger.level = Logger::DEBUG if development?
    logger.datetime_format = ''
    logger
  end

end
