
class Test::Unit::TestCase

  def read_file_from_pepys_diary(date)
    File.read("#{File.dirname(__FILE__)}/pepy/#{date}.txt")
  end

  def create_article_from_pepys_diary(date, attributes={})
    attributes[:body] = read_file_from_pepys_diary(date)
    attributes[:slug] ||= date
    attributes[:title] ||= date
    Article.create!(attributes)
  end

  def create_test_entries_from_pepys_diary
    create_article_from_pepys_diary '1659-01-01',
      :summary => "Pepy's first journal entry ...",
      :title => "Sunday 1 January 1659/60"
  end

  def create_test_bookmark(slug, options={})
    options = { :slug => slug, :title => slug }.merge(options)
    Bookmark.create!(options)
  end

end
