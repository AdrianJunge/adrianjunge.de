module SeoHelper
  SITE_NAME = "vurlo".freeze
  SITE_AUTHOR = "Adrian Junge".freeze
  DEFAULT_DESCRIPTION =
    "Security research, CVEs, bug bounty work, source review, CTF writeups, and technical notes by Adrian Junge.".freeze
  DEFAULT_IMAGE = "landing/profile.png".freeze

  def seo_meta_tags(title: nil, description: DEFAULT_DESCRIPTION, type: "website", canonical_path: nil,
                    image: DEFAULT_IMAGE, noindex: false, published_time: nil, modified_time: nil, tags: [],
                    section: nil, authors: [], json_ld: nil)
    page_title = seo_title(title)
    page_description = seo_description(description)
    canonical = canonical_url(canonical_path)
    image_url = seo_image_url(image)
    tag_values = Array(tags).map(&:to_s).reject(&:blank?)
    author_values = seo_author_names(authors)

    meta_tags = [
      content_tag(:title, page_title),
      tag.meta(name: "description", content: page_description),
      tag.meta(name: "author", content: SITE_AUTHOR),
      tag.meta(name: "robots", content: noindex ? "noindex, nofollow" : "index, follow"),
      tag.meta(property: "og:site_name", content: SITE_NAME),
      tag.meta(property: "og:locale", content: "en_US"),
      tag.meta(property: "og:title", content: page_title),
      tag.meta(property: "og:description", content: page_description),
      tag.meta(property: "og:type", content: type),
      tag.meta(name: "twitter:card", content: image_url.present? ? "summary_large_image" : "summary"),
      tag.meta(name: "twitter:title", content: page_title),
      tag.meta(name: "twitter:description", content: page_description)
    ]

    unless noindex
      meta_tags << tag.link(rel: "canonical", href: canonical)
      meta_tags << tag.meta(property: "og:url", content: canonical)
    end

    if image_url.present?
      meta_tags << tag.meta(property: "og:image", content: image_url)
      meta_tags << tag.meta(name: "twitter:image", content: image_url)
    end

    if type == "article"
      meta_tags << tag.meta(property: "article:published_time", content: seo_time(published_time)) if published_time.present?
      meta_tags << tag.meta(property: "article:modified_time", content: seo_time(modified_time)) if modified_time.present?
      meta_tags << tag.meta(property: "article:section", content: seo_plain_text(section)) if section.present?
      author_values.each { |author_name| meta_tags << tag.meta(property: "article:author", content: author_name) }
      tag_values.each { |tag_name| meta_tags << tag.meta(property: "article:tag", content: tag_name) }
    end

    meta_tags << json_ld_tag(json_ld) if json_ld.present?

    safe_join(meta_tags, "\n")
  end

  def seo_website_schema(description: DEFAULT_DESCRIPTION)
    {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => SITE_NAME,
      "alternateName" => SITE_AUTHOR,
      "url" => canonical_url(root_path),
      "description" => seo_description(description),
      "author" => seo_person_reference,
      "potentialAction" => {
        "@type" => "SearchAction",
        "target" => {
          "@type" => "EntryPoint",
          "urlTemplate" => canonical_url("#{timeline_path}?q={search_term_string}")
        },
        "query-input" => "required name=search_term_string"
      }
    }
  end

  def seo_person_schema(description: DEFAULT_DESCRIPTION)
    {
      "@context" => "https://schema.org",
      "@type" => "Person",
      "name" => SITE_AUTHOR,
      "alternateName" => "vurlo",
      "url" => canonical_url(about_path),
      "image" => seo_image_url(DEFAULT_IMAGE),
      "description" => seo_description(description),
      "sameAs" => [
        "https://github.com/AdrianJunge/",
        "https://www.linkedin.com/in/adrian-junge-998a63296/",
        "https://ctftime.org/team/7221/"
      ],
      "affiliation" => [
        { "@type" => "CollegeOrUniversity", "name" => "Karlsruhe Institute of Technology", "url" => "https://www.kit.edu/" },
        { "@type" => "Organization", "name" => "FZI Forschungszentrum fuer Informatik", "url" => "https://www.fzi.de/" },
        { "@type" => "Organization", "name" => "KITCTF", "url" => "https://kitctf.de/" }
      ]
    }
  end

  def seo_collection_schema(title:, description:, canonical_path:, items: [])
    schema = {
      "@context" => "https://schema.org",
      "@type" => "CollectionPage",
      "name" => seo_plain_text(title),
      "description" => seo_description(description),
      "url" => canonical_url(canonical_path),
      "isPartOf" => {
        "@type" => "WebSite",
        "name" => SITE_NAME,
        "url" => canonical_url(root_path)
      }
    }

    item_list = seo_item_list_schema(items)
    schema["mainEntity"] = item_list if item_list.present?
    schema
  end

  def seo_article_schema(title:, description:, canonical_path:, published: nil, modified: nil, tags: [],
                         image: DEFAULT_IMAGE, section: nil, authors: [])
    author_refs = seo_author_references(authors)
    schema = {
      "@context" => "https://schema.org",
      "@type" => "TechArticle",
      "headline" => seo_plain_text(title),
      "description" => seo_description(description),
      "url" => canonical_url(canonical_path),
      "image" => seo_image_url(image),
      "author" => author_refs.length == 1 ? author_refs.first : author_refs,
      "publisher" => seo_person_reference
    }

    schema["datePublished"] = seo_time(published) if published.present?
    schema["dateModified"] = seo_time(modified) if modified.present?
    schema["keywords"] = Array(tags).map(&:to_s).reject(&:blank?).join(", ") if tags.present?
    schema["articleSection"] = seo_plain_text(section) if section.present?
    schema
  end

  private

  def seo_title(title)
    clean_title = seo_plain_text(title)
    return SITE_NAME if clean_title.blank? || clean_title == SITE_NAME

    "#{clean_title} | #{SITE_NAME}"
  end

  def seo_description(description)
    seo_plain_text(description).presence || DEFAULT_DESCRIPTION
  end

  def seo_plain_text(value)
    strip_tags(value.to_s).squish
  end

  def canonical_url(path = nil)
    target = path.presence || request.path
    return target if target.to_s.match?(%r{\Ahttps?://}i)

    normalized_path = target.to_s.start_with?("/") ? target.to_s : "/#{target}"
    "#{request.base_url}#{normalized_path}"
  end

  def seo_image_url(image)
    selected_image = image.presence || DEFAULT_IMAGE
    return selected_image if selected_image.to_s.match?(%r{\Ahttps?://}i)

    asset_url(selected_image)
  rescue StandardError
    nil
  end

  def seo_time(value)
    return value.iso8601 if value.respond_to?(:iso8601)

    Time.zone.parse(value.to_s).iso8601
  rescue StandardError
    nil
  end

  def seo_person_reference
    {
      "@type" => "Person",
      "name" => SITE_AUTHOR,
      "url" => canonical_url(about_path)
    }
  end

  def seo_item_list_schema(items)
    item_elements = Array(items).filter_map do |item|
      title = seo_item_title(item)
      url = seo_item_url(item)
      next if title.blank? || url.blank?

      {
        "@type" => "ListItem",
        "name" => title,
        "url" => url
      }
    end

    return nil if item_elements.empty?

    {
      "@type" => "ItemList",
      "itemListElement" => item_elements.each_with_index.map { |item, index| item.merge("position" => index + 1) }
    }
  end

  def seo_item_title(item)
    if item.respond_to?(:[])
      seo_plain_text(item[:title].presence || item["title"].presence || item[:name].presence || item["name"].presence)
    else
      seo_plain_text(item)
    end
  end

  def seo_item_url(item)
    return nil unless item.respond_to?(:[])

    raw_url = item[:link].presence || item["link"].presence || item[:url].presence || item["url"].presence
    canonical_url(raw_url) if raw_url.present?
  end

  def seo_author_references(authors)
    normalized_authors = authors.is_a?(Hash) ? [ authors ] : Array(authors)

    references = normalized_authors.filter_map do |author|
      name = seo_author_name(author)
      next if name.blank?

      reference = {
        "@type" => "Person",
        "name" => name
      }
      url = seo_author_url(author)
      reference["url"] = canonical_url(url) if url.present?
      reference
    end

    references.presence || [ seo_person_reference ]
  end

  def seo_author_names(authors)
    seo_author_references(authors).filter_map { |author| author["name"].presence }
  end

  def seo_author_name(author)
    if author.is_a?(Hash)
      seo_plain_text(author["name"].presence || author[:name].presence)
    else
      seo_plain_text(author)
    end
  end

  def seo_author_url(author)
    return nil unless author.is_a?(Hash)

    urls = author["urls"].presence || author[:urls].presence || author["url"].presence || author[:url].presence
    Array(urls).map(&:to_s).find(&:present?)
  end

  def json_ld_tag(data)
    content_tag(
      :script,
      ERB::Util.json_escape(data.to_json).html_safe,
      type: "application/ld+json"
    )
  end
end
