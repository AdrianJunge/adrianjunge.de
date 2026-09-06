xml.instruct!
xml.feed xmlns: "http://www.w3.org/2005/Atom" do
  xml.id                    @feed_alternate_url
  xml.title                 @feed_title
  xml.subtitle              @feed_description
  xml.updated               @feed_updated.iso8601
  xml.link                  rel: "self", href: @feed_self_url
  xml.link                  rel: "alternate", href: @feed_alternate_url
  xml.author do
    xml.name "Adrian Junge"
    xml.uri about_url
  end

  @items.each do |item|
    xml.entry do
      xml.id              item[:guid]
      xml.title           item[:title]
      xml.category        term: item[:source]
      xml.link            rel: "alternate", href: item[:link]
      xml.updated         item[:modified].iso8601
      xml.published       item[:pub_date].iso8601
      xml.summary         type: "html" do
        xml.cdata!        item[:description].to_s
      end
    end
  end
end
