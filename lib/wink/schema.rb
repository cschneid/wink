require 'wink'

module Wink

  # Utility methods for initializing, migrating, and tearing down
  # a Wink database schema.
  module Schema
    extend self

    # Configure the default DataMapper database. This method delegates to 
    # DataMapper::Database::setup but guards against Sinatra reloading.
    def configure(options)
      DataMapper::Database.setup(options) unless reloading?
    end

    # Create the database schema using the current default DataMapper
    # database. When the :force option is true, drop the table (if it exists)
    # before creating. An exception is raised when :force is false (default) and
    # tables already exist.
    def create!(options={})
      force = !! options[:force]
      model_classes.each { |model| model.table.create!(force) }
      create_welcome_entry! if options[:welcome]
      true
    end

    # Drop all Wink tables from the current default DataMapper database.
    def drop!
      model_classes.each { |model| model.table.drop! }
      true
    end

    # Create the welcome entry. If an existing welcome entry already exists,
    # it is removed.
    def create_welcome_entry!
      remove_welcome_entry!
      Article.create! :slug => 'welcome' do |a|
        a.slug = 'welcome'
        a.title = 'Hiya!'
        a.summary = 'A brief introduction to Wink.'
        a.published = true
        a.body = (<<-end).gsub(/^\s{10}/, '')
          Foo bar baz ...
        end
      end
    end

    # Remove the welcome entry.
    def remove_welcome_entry!
      if article = Article.first(:slug => 'welcome')
        article.destroy!
        true
      end
    end

  private

    # All model classes that have corresponding tables (i.e., STI subclasses
    # are not included).
    def model_classes
      require 'wink/models'
      @model_classes ||= [ Entry, Comment, Tag, Tagging ].freeze
    end

  end

end

# DEPRECATED: The top-level Database constant will be removed before the next
# release.
Database = Wink::Schema
