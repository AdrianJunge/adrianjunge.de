class ContentConfiguration
  BASE_PATH = Rails.root.join("app", "assets", "ctf", "writeups")
  CTF_INFO_PATH = Rails.root.join("app", "assets", "ctf", "ctfs.json")
  CTF_RESOURCE_BASE_PATH = Rails.root.join("content", "ctf")
  CTF_CHALLENGE_FILES_PATH = CTF_RESOURCE_BASE_PATH.join("files")
  CTF_PDF_WRITEUPS_PATH = CTF_RESOURCE_BASE_PATH.join("writeups")
  BLOG_BASE_PATH = Rails.root.join("app", "assets", "blog", "posts")
  BLOG_INFO_PATH = Rails.root.join("app", "assets", "blog", "blogs.json")
  ABOUTME_BASE_PATH = Rails.root.join("app", "assets", "aboutme")
  ABOUTME_TEXT_PATH = ABOUTME_BASE_PATH.join("about.md")
  ABOUTME_CVES_PATH = ABOUTME_BASE_PATH.join("cves.json")
  ABOUTME_BUG_BOUNTIES_PATH = ABOUTME_BASE_PATH.join("bug_bounties.json")
  ABOUTME_CHALLENGES_PATH = ABOUTME_BASE_PATH.join("challenges.json")
  ABOUTME_CERTIFICATES_PATH = ABOUTME_BASE_PATH.join("certificates.json")
  ABOUTME_TALKS_PATH = ABOUTME_BASE_PATH.join("talks.json")
  ABOUTME_ACHIEVEMENTS_PATH = ABOUTME_BASE_PATH.join("achievements.json")

  def initialize(root: Rails.root)
    @root = Pathname(root)
    freeze
  end

  def path(name)
    @root.join(self.class.const_get(name).relative_path_from(Rails.root))
  end

  def resolve(path)
    candidate = Pathname(path)
    return candidate unless self.class.constants(false).any? { |name| self.class.const_get(name) == candidate }

    @root.join(candidate.relative_path_from(Rails.root))
  end

  def schema_path(path)
    candidate = Pathname(path)
    name = self.class.constants(false).find { |key| self.path(key) == candidate }
    name ? self.class.const_get(name) : candidate
  end
end
