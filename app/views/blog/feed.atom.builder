xml.instruct!
xml.feed xmlns: "http://www.w3.org/2005/Atom" do
  xml.id                    root_url
  xml.title                 "Blog Posts"
  xml.updated               (@items.first ? @items.first[:pub_date].iso8601 : Time.now.iso8601)
  xml.link                  rel: "self", href: blog_path(format: :atom)
  xml.link                  rel: "alternate", href: root_url

  @items.each do |item|
    xml.entry do
      xml.id              item[:guid]
      xml.title           item[:title]
      xml.link            rel: "alternate", href: item[:link]
      xml.updated         item[:pub_date].iso8601
      xml.published       item[:pub_date].iso8601
      xml.summary         type: "html" do
        xml.cdata!        item[:description].to_s
      end
    end
  end
end
