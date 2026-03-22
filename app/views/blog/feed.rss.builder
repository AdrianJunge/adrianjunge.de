xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss(version: "2.0") do
  xml.channel do
    xml.title       "Blog Posts"
    xml.link        root_url
    xml.description "Latest Blog Posts"
    xml.language    "en"
    xml.pubDate     @items.first[:pub_date].rfc2822 if @items.any?
    xml.lastBuildDate Time.now.rfc2822

    @items.each do |item|
      xml.item do
        xml.title item[:title]
        xml.description { xml.cdata! item[:description].to_s }
        xml.link item[:link]
        xml.guid item[:guid]
        xml.pubDate item[:pub_date].rfc2822
      end
    end
  end
end
