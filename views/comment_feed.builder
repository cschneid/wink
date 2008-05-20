xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title   @title || "Recent Comments"
  xml.link    "rel" => "self", "href" => request.url
  xml.link    "rel" => "alternate", "href" => request.url.sub(/feed$/, '')
  xml.id      request.url
  xml.updated @comments.first.created_at.iso8601 if @comments.any?
  xml.author  { xml.name "Various Artists" }
  @comments.each do |comment|
    xml.entry do
      xml.title   comment.excerpt
      xml.link    "rel"  => "alternate", 
                  "href" => h(entry_url(comment.entry) + "#comment-#{comment.id}")
      xml.id      "tag:naeblis.cx,2003:comment/#{comment.id}"
      xml.published comment.created_at.iso8601
      xml.updated   comment.created_at.iso8601
      xml.author  { xml.name comment.author }
      xml.summary ''
      xml.content content_filter(comment.body_with_links, :markdown),
          "type" => "html"
    end
  end

end

# vim: ts=2 sw=2 sts=2 expandtab
