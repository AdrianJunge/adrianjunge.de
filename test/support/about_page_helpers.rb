module AboutPageHelpers
  private

  def about_section_cases(repository)
    presentation = {
      "cves" => { title: "CVEs", stat_label: "CVEs", singular: "entry", plural: "entries" },
      "bug-bounties" => { title: "Bug bounties", stat_label: "Bug bounties", singular: "finding", plural: "findings" },
      "my-challenges" => { title: "Created CTF Challenges", stat_label: "Created CTF Challenges", singular: "challenge", plural: "challenges" },
      "certificates" => { title: "Certificates", stat_label: "Certificates", singular: "certificate", plural: "certificates" },
      "talks" => { title: "Talks", stat_label: "Talks", singular: "talk", plural: "talks" },
      "achievements" => { title: "Relevant achievements", stat_label: "Achievements", singular: "event", plural: "events" }
    }

    ContentTestHelpers::ABOUT_COLLECTIONS.map do |spec|
      entries = about_collection_entries(spec, repository: repository)
      spec.merge(presentation.fetch(spec.fetch(:id))).merge(
        entries: entries,
        count: spec.fetch(:count).call(repository, entries)
      )
    end
  end

  def assert_about_catalog_rendered(section_cases)
    section_cases.each do |section|
      selector = "##{section.fetch(:id)}"
      rendered_ids = all("#{selector} #{section.fetch(:card_selector)}", visible: :all).map { |card| card["id"] }.sort

      assert_equal section.fetch(:entries).map { |entry| entry.fetch("id") }.sort, rendered_ids
      assert_selector "#{selector} .aboutme-section-title", text: section.fetch(:title)
      assert_selector ".aboutme-stat[href='##{section.fetch(:id)}'] .aboutme-stat-value", text: /^#{section.fetch(:count)}$/
      assert_selector ".aboutme-stat[href='##{section.fetch(:id)}']", text: section.fetch(:stat_label)

      if section.fetch(:entries).empty?
        assert_selector "#{selector} .aboutme-empty-state"
      else
        assert_no_selector "#{selector} .aboutme-empty-state", visible: :all
      end
    end
  end

  def assert_about_links_rendered(section_cases)
    section_cases.each do |section|
      section.fetch(:entries).each do |entry|
        card = find("##{entry.fetch('id')}", visible: :all)
        tags = normalized_about_tags(entry["tags"])
        ordered_tags = tags.partition { |tag| tag[:url].blank? }.flatten

        within card do
          assert_equal ordered_tags.map { |tag| tag.fetch(:label) },
                       all(".aboutme-card-tags > *", visible: :all).map { |tag| tag.text.squish }

          ordered_tags.select { |tag| tag[:url].present? }.each do |tag|
            rendered_tag = all("a.aboutme-card-tag", visible: :all).find do |link|
              href_matches?(tag.fetch(:url), link["href"])
            end
            assert rendered_tag, "expected #{entry['id']} to link tag #{tag[:label]} to #{tag[:url]}"
          end

          expected_links = Array(entry["links"]).select do |link|
            link.is_a?(Hash) && link["label"].present? && link["url"].present?
          end
          rendered_links = all("a.aboutme-reference-link", visible: :all)
          assert_equal expected_links.map { |link| link["label"] }, rendered_links.map { |link| link.text(:all).squish }
          expected_links.zip(rendered_links).each do |expected, rendered|
            assert href_matches?(expected.fetch("url"), rendered["href"])
          end

          expected_events = Array(entry["timeline"]).select do |event|
            event.is_a?(Hash) && (event["title"].present? || event["event"].present?)
          end
          rendered_events = all(".aboutme-timeline li", visible: :all)
          assert_equal expected_events.length, rendered_events.length

          expected_events.zip(rendered_events).each do |event, rendered_event|
            label = event["title"].presence || event["event"]
            assert_equal label, rendered_event.find(".aboutme-timeline-link, .aboutme-timeline-title", visible: :all).text(:all).squish
            assert_equal event["date"], rendered_event.find("time", visible: :all)["datetime"] if event["date"].present?
            if event["url"].present?
              rendered_href = rendered_event.find("a.aboutme-timeline-link", visible: :all)["href"]
              assert href_matches?(event.fetch("url"), rendered_href)
            end
          end
        end
      end
    end
  end

  def normalized_about_tags(raw_tags)
    Array(raw_tags).filter_map do |tag|
      if tag.is_a?(Hash)
        label = tag["label"].presence || tag["name"].presence
        next if label.blank?

        { label: ContentTagTaxonomy.canonical_label(label), url: tag["url"].presence }
      elsif tag.to_s.present?
        { label: ContentTagTaxonomy.canonical_label(tag), url: nil }
      end
    end
  end

  def achievement_anchor_case
    production_content_repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).each do |achievement|
      event = Array(achievement["timeline"]).find { |candidate| candidate["id"].present? }
      return [ achievement, event ] if event
    end

    flunk("expected an achievement timeline event with an anchor")
  end

  def cve_visual_case
    production_content_repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).find do |entry|
      cve_tag_from(entry) && cwe_tag_from(entry) &&
        about_reference_links(entry).length >= 2 &&
        entry["summary"].present?
    end || flunk("expected a CVE with vulnerability tags, references, and details")
  end

  def challenge_visual_case
    production_content_repository.authored_challenges.find do |entry|
      entry["summary"].present? && normalized_about_tags(entry["tags"]).any? do |tag|
        tag[:url].to_s.match?(%r{\Ahttps?://})
      end
    end || flunk("expected an authored challenge with a linked tag and details")
  end

  def cve_tag_from(entry)
    Array(entry["tags"]).find do |tag|
      tag.is_a?(Hash) && tag["url"].present? && ContentVulnerabilityTag.cve?(tag["label"])
    end
  end

  def cwe_tag_from(entry)
    Array(entry["tags"]).find do |tag|
      tag.is_a?(Hash) && tag["url"].present? && ContentVulnerabilityTag.cwe?(tag["label"])
    end
  end

  def about_reference_links(entry)
    Array(entry["links"]).select do |link|
      link.is_a?(Hash) && link["label"].present? && link["url"].present?
    end
  end

  def authored_challenge_writeup_case
    production_content_repository.authored_challenges.each do |challenge|
      tag = Array(challenge["tags"]).find do |candidate|
        candidate.is_a?(Hash) && candidate["url"].to_s.start_with?("/ctf/")
      end
      next unless tag

      post = production_content_repository.ctf_posts.find do |candidate|
        CGI.unescape(candidate[:link]) == CGI.unescape(tag.fetch("url"))
      end
      return [ challenge, tag, post ] if post
    end

    flunk("expected an authored challenge linked to a published writeup")
  end

  def href_matches?(expected, actual)
    expected = expected.to_s
    actual = actual.to_s
    return expected == actual unless expected.start_with?("/")

    uri = URI.parse(actual)
    rendered_path = uri.path
    rendered_path += "?#{uri.query}" if uri.query
    rendered_path += "##{uri.fragment}" if uri.fragment
    rendered_path == expected
  rescue URI::InvalidURIError
    false
  end
end
