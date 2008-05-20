task :default => :test

desc 'Run tests'
task :test do
  ruby 'test.rb'
end

task :environment do
  require 'weblog'
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
