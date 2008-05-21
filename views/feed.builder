xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title   @title || @author
  xml.link    "rel" => "self", "href" => request.url
  xml.link    "rel" => "alternate", "href" => request.url.sub(/feed$/, '')
  xml.id      request.url
  xml.updated @entries.first.updated_at.iso8601 if @entries.any?
  xml.author  { xml.name @author }
  @entries.each do |@entry|
    xml.entry do
      xml.title   @entry.title
      xml.link    "rel" => "alternate", "href" => h(entry_url(@entry))
      xml.id      @entry.tag_id
      xml.published @entry.created_at.iso8601
      xml.updated   @entry.created_at.iso8601
      xml.author  { xml.name "Ryan Tomayko" }
      xml.summary "type" => "xhtml" do
        xml.div :xmlns => 'http://www.w3.org/1999/xhtml' do
          xml << content_filter(@entry.summary, :markdown)
        end
      end
      if @entry.body?
        xml.content "type" => "xhtml" do
          xml.div :xmlns=>'http://www.w3.org/1999/xhtml' do
            xml << content_filter(@entry.body, @entry.filter)
          end
        end
      end
    end
  end

end
