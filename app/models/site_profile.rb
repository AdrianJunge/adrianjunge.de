require "uri"

# The public identity belongs to the site, independently of a request's host.
module SiteProfile
  NAME = "Adrian Junge".freeze
  HANDLE = "vurlo".freeze
  ORIGIN = "https://adrianjunge.de".freeze
  FEED_TITLE = "adrianjunge.de".freeze
  EMAIL = "todo@adrianjunge.de".freeze
  PGP_PATH = "/pgp-vurlo.asc".freeze
  SOURCE_URL = "https://github.com/AdrianJunge/adrianjunge.de".freeze
  BUG_BOUNTY_COUNT = 4
  # Update when editing profile copy, identity, or undated About information.
  # This is an editorial date, never the deployment or checkout timestamp.
  MODIFIED = "2026-09-27".freeze
  DESCRIPTION = "Security research, CVEs, bug bounty work, source review, CTF writeups, and technical notes by #{NAME}.".freeze
  SOCIAL_LINKS = {
    github: "https://github.com/AdrianJunge/",
    linkedin: "https://www.linkedin.com/in/adrian-junge-998a63296/",
    discord: "https://discord.com/users/305624492221267968/",
    telegram: "https://t.me/FullyIncredibleCreativeUsername",
    instagram: "https://www.instagram.com/adrian_jnge/"
  }.transform_values(&:freeze).freeze
  AFFILIATIONS = [
    { "@type" => "CollegeOrUniversity", "name" => "Karlsruhe Institute of Technology", "url" => "https://www.kit.edu/" },
    { "@type" => "Organization", "name" => "KITCTF", "url" => "https://kitctf.de/" }
  ].map { |entry| entry.transform_values(&:freeze).freeze }.freeze

  module_function

  def name = NAME
  def handle = HANDLE
  def origin = ORIGIN
  def feed_title = FEED_TITLE
  def email = EMAIL
  def email_url = "mailto:#{email}"
  def pgp_path = PGP_PATH
  def source_url = SOURCE_URL
  def bug_bounty_count = BUG_BOUNTY_COUNT
  def modified = MODIFIED
  def description = DESCRIPTION
  def social_links = SOCIAL_LINKS
  def affiliations = AFFILIATIONS

  def url_options
    { host: URI(origin).host, protocol: "https" }
  end

  def absolute_url(path)
    raw = path.to_s
    return raw if raw.match?(%r{\Ahttps?://}i)

    "#{origin}#{ContentUrl.encoded_path("/#{raw.delete_prefix('/')}")}"
  end

  def author
    { name: name, url: absolute_url("/about") }
  end
end
