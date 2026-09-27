xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss(version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom", "xmlns:dc" => "http://purl.org/dc/elements/1.1/") do
  xml.channel do
    xml.title       @feed_title
    xml.link        @feed_alternate_url
    xml.tag!        "atom:link", href: @feed_self_url, rel: "self", type: "application/rss+xml"
    xml.description @feed_description
    xml.language    "en"
    xml.pubDate     @feed_updated.rfc2822
    xml.lastBuildDate @feed_updated.rfc2822

    @items.each do |item|
      xml.item do
        xml.title item[:title]
        xml.category item[:source]
        xml.description { xml.cdata! item[:description].to_s }
        xml.link item[:link]
        xml.guid item[:guid]
        xml.pubDate item[:pub_date].rfc2822
        item[:authors].each { |author| xml.tag! "dc:creator", author[:name] }
      end
    end
  end
end
