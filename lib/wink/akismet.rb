# Akismet API Support.
# Copyright (c) 2008 Ryan Tomayko
#
# Based on David Czarnecki's akismet.rb
# Copyright (c) 2005 David Czarnecki

require 'net/http'
require 'uri'

module Wink

  # An interface to the Akismet spam detection service.
  #
  # === Comment Information
  # 
  # The various Akismet request methods (e.g., #spam!, #ham!, #check) supported by this
  # class take a +params+ argument, which is a Hash of the following key values:
  #
  # <tt>:user_ip</tt> (required)::
  #    IP address of the comment submitter. Care must be taken to get this right when
  #    a gateway/reverse proxy or other intermediary is involved in the
  #    request. The +X-Forwarded-For+ request header can often be used to determine
  #    the IP in these scenarios.
  #
  # <tt>:user_agent</tt> (required)::
  #    The +User-Agent+ request header included with the comment submission
  #    request.
  #
  # <tt>:referrer</tt> (optional)::
  #    The +Referer+ request header included with the comment submission
  #
  # <tt>:permalink</tt> (optional)::
  #    The permanent location of the entry the comment was submitted to.
  #
  # <tt>:comment_type</tt> (optional)::
  #    May be blank, comment, trackback, pingback, or a made up value like "registration".
  #
  # <tt>:comment_author</tt> (optional)::
  #    Comment author's full name.
  #
  # <tt>:comment_author_email</tt> (optional)::
  #    Comment author's email address.
  #
  # <tt>:comment_author_url</tt> (optional)::
  #    Comment author's URL.
  #
  # <tt>:comment_content</tt> (optional)::
  #    The content of the comment that was submitted.
  #
  # === Other server enviroment variables
  #
  # In PHP there is an array of enviroment variables called $_SERVER which
  # contains information about the web server itself as well as a key/value
  # for every HTTP header sent with the request. This data is highly useful
  # to Akismet as how the submited content interacts with the server can be
  # very telling, so please include as much information as possible.
  #
  # === See Also
  #
  # {Offical Akismet API Documentation}[http://akismet.com/development/api/]
  # {David Czarnecki akismet.rb}[http://www.blojsom.com/blog/nerdery/2005/12/02/Akismet-API-in-Ruby.html]
  #
  class Akismet

    # Hash of request headers included with Akismet requests.
    STANDARD_HEADERS = {
      'User-Agent'   => "Wink/#{Wink::VERSION} | Akismet Ruby API/1.0",
      'Content-Type' => 'application/x-www-form-urlencoded'
    }

    # The URL of the blog or website that uses Akismet.
    attr_reader :url

    # The API key associate with the blog or website URL.
    attr_reader :key

    # A Hash of request headers delivered with each request.

    # Create a new Akismet call site. The +key+ and +url+ arguments are
    # required and 
    def initialize(key, url, headers={})
      raise ArgumentError, "Expected key and url" if [key,url].any?{ |v| v.nil? }
      @key = key
      @url = url
      @headers = STANDARD_HEADERS.dup.merge(headers)
      @verified = false
    end

    # Has the key been verified?
    def verified?
      @verified
    end

    # Call to check and verify your API key. You may then call the #verified? method to see if
    # your key has been validated.
    def verify!
      return true if verified?
      http = Net::HTTP.new('rest.akismet.com', 80)
      resp, data = http.post('/1.1/verify-key', "key=#{@key}&blog=#{@blog}", @headers)
      @verified = (data == "valid")
    end

    # This is basically the core of everything. This call takes a number of
    # arguments and characteristics about the submitted content and then returns
    # a thumbs up or thumbs down. Almost everything is optional, but performance
    # can drop dramatically if you exclude certain elements.
    def check(params={})
      call 'comment-check', params
    end

    # This call is for submitting comments that weren't marked as spam but
    # should have been. It takes identical arguments as comment check.
    def spam!(params={})
      call 'submit-spam', params
    end

    # This call is intended for the marking of false positives, things that were
    # incorrectly marked as spam. It takes identical arguments as comment check
    # and submit spam.
    def ham!(params={})
      call 'submit-ham', params
    end

  private

    # Regular expression used for escaping parameters in the Akismet post
    # body. This is used in place of URL::REGEXP::UNSAFE.
    #
    ESCAPE_CHARS = Regexp.union(URI::REGEXP::UNSAFE, /[&?=]/n)

    # Internal call to Akismet. Prepares the data for posting to the Akismet service.
    #
    # The +params+ Hash keys are described in the Akismet class documentation.
    def call(method, params={})
      params = params.reject{|k,v| v.nil?}.merge(:blog => @url)
      res =
        Net::HTTP.start("#{@key}.rest.akismet.com", 80) do |http|
          http.post("/1.1/#{method}", post_data(params), headers)
        end
      res.body == "true"
    end

    # Convert the Hash provided into a URL encoded string suitable for passing
    # to Akismet's POST messages.
    def post_data(params={})
      params.
        reject { |k,v| k.nil? }.
        merge(:blog => @url).
        collect { |k,v| [k, URI.escape(v, ESCAPE_CHARS)].join('=') }.
        join('&')
    end

  end

end
