require 'net/http'
require 'uri'

class Akismet

  STANDARD_HEADERS = {
    'User-Agent'   => 'Akismet Ruby API/1.0 | naeblis.cx/1.0',
    'Content-Type' => 'application/x-www-form-urlencoded'
  }

  # Create a new instance of the Akismet class
  #
  # key
  #   Your Akismet API key
  # blog
  #   The blog associated with your api key
  def initialize(key, blog)
    @key = key
    @blog = blog
    @verified = false
  end

  # Has the key been verified?
  def verified?
    @verified
  end

  # Call to check and verify your API key. You may then call the #verified? method to see if
  # your key has been validated.
  def verify!
    @verified ||= begin
      http = Net::HTTP.new('rest.akismet.com', 80)
      path = '/1.1/verify-key'
      resp, data = http.post(path, "key=#{@key}&blog=#{@blog}", STANDARD_HEADERS)
      data == "valid"
    end
  end

  # Internal call to Akismet. Prepares the data for posting to the Akismet service.
  #
  # function
  #   The Akismet function that should be called
  # user_ip (required)
  #    IP address of the comment submitter.
  # user_agent (required)
  #    User agent information.
  # referrer (note spelling)
  #    The content of the HTTP_REFERER header should be sent here.
  # permalink
  #    The permanent location of the entry the comment was submitted to.
  # comment_type
  #    May be blank, comment, trackback, pingback, or a made up value like "registration".
  # comment_author
  #    Submitted name with the comment
  # comment_author_email
  #    Submitted email address
  # comment_author_url
  #    Commenter URL.
  # comment_content
  #    The content that was submitted.
  # Other server enviroment variables
  #    In PHP there is an array of enviroment variables called $_SERVER which contains information about the web server itself as well as a key/value for every HTTP header sent with the request. This data is highly useful to Akismet as how the submited content interacts with the server can be very telling, so please include as much information as possible.
  def call(function, params={})
    escape_chars = Regexp.union(URI::REGEXP::UNSAFE, /[&?=]/n)
    params = params.reject{|k,v| v.nil?}.merge(:blog => @blog)
    http = Net::HTTP.new("#{@key}.rest.akismet.com", 80)
    path = "/1.1/#{function}"
    data = params.collect do |name,value|
      "#{name}=#{URI.escape(value, escape_chars)}"
    end.join('&')
    resp, data = http.post(path, data, STANDARD_HEADERS)
    data == "true"
  end

  # This is basically the core of everything. This call takes a number of arguments and characteristics about the submitted content and then returns a thumbs up or thumbs down. Almost everything is optional, but performance can drop dramatically if you exclude certain elements.
  #
  # user_ip (required)
  #    IP address of the comment submitter.
  # user_agent (required)
  #    User agent information.
  # referrer (note spelling)
  #    The content of the HTTP_REFERER header should be sent here.
  # permalink
  #    The permanent location of the entry the comment was submitted to.
  # comment_type
  #    May be blank, comment, trackback, pingback, or a made up value like "registration".
  # comment_author
  #    Submitted name with the comment
  # comment_author_email
  #    Submitted email address
  # comment_author_url
  #    Commenter URL.
  # comment_content
  #    The content that was submitted.
  # Other server enviroment variables
  #    In PHP there is an array of enviroment variables called $_SERVER which contains information about the web server itself as well as a key/value for every HTTP header sent with the request. This data is highly useful to Akismet as how the submited content interacts with the server can be very telling, so please include as much information as possible.
  def check_comment(params={})
    call('comment-check', params)
  end

  # This call is for submitting comments that weren't marked as spam but should have been. It takes identical arguments as comment check.
  # The call parameters are the same as for the #commentCheck method.
  def submit_spam(params={})
    call('submit-spam', params)
  end

  # This call is intended for the marking of false positives, things that were incorrectly marked as spam. It takes identical arguments as comment check and submit spam.
  # The call parameters are the same as for the #commentCheck method.
  def submit_ham(params={})
    call('submit-ham', params)
  end

end
