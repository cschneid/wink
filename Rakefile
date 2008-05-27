require 'rake/clean'

task :default => :test

desc 'Run tests'
task :test do
  sh "testrb test/*_test.rb"
end

desc 'Run specs'
task :spec do
  sh "specrb -s test/*_test.rb"
end

desc 'Start a development server'
task :start do
  command = "ruby wink -e #{wink_environment}"
  STDERR.puts(command) if verbose
  exec(command)
end


# Environment Configuration ==================================================

def wink_environment
  if ENV['WINK_ENV']
    ENV['WINK_ENV'].to_sym
  elsif defined?(Sinatra)
    Sinatra.application.options.env
  else
    :development
  end
end

task :environment do
  $:.unshift 'sinatra/lib' if File.exist?('sinatra')
  $:.unshift 'lib'
  $:.unshift '.'
  require 'wink'
  Wink.configure 'wink.conf' do
    set :env, wink_environment
  end
end


# Database Related Tasks ====================================================

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


# Documentation Tasks ========================================================

desc 'Generate documentation and website (doc/)'
task 'doc' => [ 'doc:todo', 'doc:api' ]

desc 'Generate Ditz HTML reports (doc/todo)'
task 'doc:todo' => ['doc/todo/index.html']

directory 'doc/todo'

file 'doc/todo/index.html' => ['doc/todo'] + FileList['bugs/*'] do |f|
  sh 'rm -rf doc/todo && ditz html doc/todo'
end

CLEAN.include 'doc/todo'

desc 'Generate API documentation'
task 'doc:api' => 'doc/api/index.html'

file 'doc/api/index.html' => FileList['lib/**/*.rb','README'] do |f|
  rb_files = f.prerequisites
  sh((<<-end).gsub(/\s+/, ' '))
    rdoc --charset utf8 \
         --fmt html \
         --inline-source \
         --line-numbers \
         --main Wink \
         --op doc/api \
         --title 'Wink API Documentation' \
         #{rb_files.join(' ')}
  end
end

CLEAN.include 'doc/api'


desc 'Publish docs to Rubyforge'
task 'doc:publish' => [ 'doc' ] do |t|
  sh 'scp -rp doc/* rubyforge.org:/var/www/gforge-projects/wink/'
end
