module ContentTestHelpers
  ABOUT_COLLECTIONS = [
    {
      id: "cves",
      path: ApplicationController::ABOUTME_CVES_PATH,
      kind: "cve",
      card_selector: ".aboutme-finding-card",
      count: ->(repository, entries) { entries.length }
    },
    {
      id: "bug-bounties",
      path: ApplicationController::ABOUTME_BUG_BOUNTIES_PATH,
      kind: "bug-bounty",
      card_selector: ".aboutme-finding-card",
      count: ->(repository, entries) { entries.length }
    },
    {
      id: "my-challenges",
      path: ApplicationController::ABOUTME_CHALLENGES_PATH,
      kind: "challenge",
      card_selector: ".aboutme-achievement-card",
      entries: ->(repository) { repository.authored_challenges },
      count: ->(repository, entries) { entries.length }
    },
    {
      id: "certificates",
      path: ApplicationController::ABOUTME_CERTIFICATES_PATH,
      kind: "certificate",
      card_selector: ".aboutme-achievement-card",
      count: ->(repository, entries) { entries.length }
    },
    {
      id: "talks",
      path: ApplicationController::ABOUTME_TALKS_PATH,
      kind: "talk",
      card_selector: ".aboutme-achievement-card",
      count: ->(repository, entries) { repository.timeline_event_count(entries) }
    },
    {
      id: "achievements",
      path: ApplicationController::ABOUTME_ACHIEVEMENTS_PATH,
      kind: "achievement",
      card_selector: ".aboutme-achievement-card",
      count: ->(repository, entries) { repository.timeline_event_count(entries) }
    }
  ].freeze

  def production_content_repository
    @production_content_repository ||= ContentRepository.new
  end

  def fixture_content_repository
    @fixture_content_repository ||= FixtureContentRepository.new
  end

  def about_collection_entries(spec, repository: production_content_repository)
    loader = spec[:entries]
    loader ? loader.call(repository) : repository.about_entries(spec.fetch(:path))
  end

  def about_tag_label(tag)
    tag.is_a?(Hash) ? tag["label"].to_s : tag.to_s
  end

  def with_stubbed_content_repository(repository)
    repository_class = ContentRepository.singleton_class
    constructor_was_defined = repository_class.instance_methods(false).include?(:new)
    original_constructor = repository_class.instance_method(:new) if constructor_was_defined
    repository_class.define_method(:new) { |*, **| repository }

    yield
  ensure
    if constructor_was_defined
      repository_class.define_method(:new, original_constructor)
    else
      repository_class.remove_method(:new)
    end
  end
end
