require File.dirname(__FILE__) + "/help"
require 'fixtures'
require 'wink/core_extensions'

describe 'DateTime' do

  it 'responds to #to_time' do
    datetime = DateTime.parse('1979-01-01T12:00:00-05:00')
    datetime.should.respond_to :to_time
    datetime.to_time.should.be == Time.parse('1979-01-01T12:00:00-05:00')
  end

  it 'responds to #iso8601' do
    datetime = DateTime.parse('1979-01-01T12:00:00-00:00')
    datetime.should.respond_to :iso8601
    datetime.iso8601.should.be == '1979-01-01T12:00:00+00:00'
  end

  it 'uses a more sane implementation of #inspect' do
    datetime = DateTime.parse('1979-01-01T12:00:00+05:00')
    datetime.inspect.should.equal '#<DateTime: 1979-01-01T12:00:00+05:00>'
  end

end


describe 'Date' do

  it 'uses a more sane implementation of #inspect' do
    datetime = Date.new(1979, 1, 1)
    datetime.inspect.should.equal '#<Date: 1979-01-01>'
  end

end


describe 'Time' do

  it 'responds to #to_datetime' do
    time = Time.iso8601('1979-01-01T12:00:00Z')
    time.iso8601.should.equal '1979-01-01T12:00:00Z'
    time.should.respond_to :to_datetime
    time.to_datetime.should.be == DateTime.parse('1979-01-01T12:00:00Z')
  end

  it 'preserves timezone information when converting to DateTime' do
    time = Time.parse('Mon Jan 01 12:10:23 PST 1979').utc
    time.iso8601.should.equal '1979-01-01T20:10:23Z'
    time.utc_offset.should.be == 0
    time.to_datetime.should.be == DateTime.parse('1979-01-01T15:10:23-05:00')
  end

end

describe 'Rack::Request#remote_ip' do

  def rack_env
    { 'HTTP_X_FORWARDED_FOR' => '11.111.111.11',
      'HTTP_CLIENT_IP' => '22.222.222.22',
      'REMOTE_ADDR' => '33.333.333.33',
      'HTTP_HOST' => 'localhost:80' }
  end

  it 'responds to' do
    Rack::Request.new(rack_env).should.respond_to :remote_ip
  end

  it 'responds with X-Forwarded-For header when present' do
    request = Rack::Request.new(rack_env)
    request.remote_ip.should.equal '11.111.111.11'
  end

  it 'responds with Client-IP header when X-Forwarded-For not present' do
    environment = rack_env
    environment.delete('HTTP_X_FORWARDED_FOR')
    request = Rack::Request.new(environment)
    request.remote_ip.should.equal '22.222.222.22'
  end

  it 'responds with REMOTE_ADDR when X-Forwarded-For or Client-IP headers not present' do
    environment = rack_env
    environment.delete('HTTP_X_FORWARDED_FOR')
    environment.delete('HTTP_CLIENT_IP')
    request = Rack::Request.new(environment)
    request.remote_ip.should.equal '33.333.333.33'
  end

end


describe 'Database' do

  it 'is defined as shortcut to DataMapper::Database' do
    Object.const_defined?(:Database).should.be.truthful
    Database.should.be DataMapper::Database
  end

  it 'responds to ::configure, ::create!, and ::drop!' do
    Database.should.respond_to :configure
    Database.should.respond_to :create!
    Database.should.respond_to :drop!
  end

end
