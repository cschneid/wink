task :default => :test

task :environment do
  $:.unshift 'sinatra/lib' if File.exist?('sinatra')
  $:.unshift 'lib'
  require 'sinatra'
  set_option :env, wink_environment
  require 'wink'
end

desc 'Run tests'
task :test do
  sh "testrb test/*_test.rb"
end

namespace :db do

  desc 'Create all database tables'
  task :init => [ :environment ] do
    Database.create!
  end

  desc 'Drop all database tables'
  task :drop => [ :environment ] do
    Database.drop!
  end

end


def wink_environment
  if ENV['WINK_ENV']
    ENV['WINK_ENV'].to_sym
  elsif defined?(Sinatra)
    Sinatra.application.options.env
  else
    :development
  end
end
