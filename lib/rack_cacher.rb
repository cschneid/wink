require 'fileutils'
require 'time'
require 'rack'

helpers do

  def purge_cache(*patterns)
    if (cache_dir = request.env['cacher.path']) && File.directory?(cache_dir)
      patterns.each do |pattern|
        paths = Dir[File.join(cache_dir, pattern)].reject { |p| p[-1] == ?+ }
        FileUtils.rmtree(paths) rescue nil
      end
    end
  end

end

class Rack::Cacher

  def initialize(app, cache_dir='./cache')
    @app = app
    @cache_dir = cache_dir
    @env = nil
  end

  def call(env)
    # let downstream know where our cache directory is
    env['cacher.path'] = @cache_dir

    # throw request downstream for processing
    res = @app.call(env)

    # Bail out if authentication information is provided
    return res if env['HTTP_AUTHORIZATION']

    request = Rack::Request.new(env)

    # Bail out if this isn't a simple GET request w/o query string
    return res unless request.get? && request.query_string.empty?

    # Bail out if the response isn't okay
    response = Rack::Response.new([], res[0], res[1])
    return res unless response.ok?

    # Bail out of we can't figure out a file extension ...
    extension = extension_for_content_type(response.content_type)
    return res if extension.nil?

    # Create the cache directory if necessary
    path = cache_path(request.path_info) + extension
    temp_path = path + "+"
    FileUtils.mkdir_p(File.dirname(path))

    # Bail out if someone else got to it first
    return res if File.exist?(path) || File.exist?(temp_path)

    # Write response to cache
    File.open(temp_path, 'wb') do |io|
      res[2].each do |chunk|
        io.write(chunk)
        response.write(chunk)
      end
    end

    # Move temporary file into place automically
    FileUtils.mv temp_path, path

    # Set the last modified time if provided
    if response['Last-Modified']
      mtime = Time.httpdate(response['Last-Modified'])
      File.utime(Time.now, mtime, path)
    end

    response.finish
  end

  def cache_path(path_info)
    case path_info
    when '', /\/$/
      File.join(@cache_dir, path_info, 'index')
    else
      File.join(@cache_dir, path_info)
    end
  end

  def extension_for_content_type(content_type)
    case content_type
    when /^(?:text|application)\/html/
      '.html'
    when /^application\/atom\+xml/
      '.atom'
    when /^(?:text|application)\/xml/
      '.xml'
    when /^text\/plain/
      '.txt'
    end
  end

end
