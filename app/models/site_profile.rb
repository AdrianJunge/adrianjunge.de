require "uri"

# The public identity belongs to the site, independently of a request's host.
module SiteProfile
  NAME = "Adrian Junge".freeze
  HANDLE = "vurlo".freeze
  ORIGIN = "https://adrianjunge.de".freeze
  FEED_TITLE = "adrianjunge.de".freeze
  EMAIL = "stdin@adrianjunge.de".freeze
  PGP_PATH = "/pgp-vurlo.asc".freeze
  SOURCE_URL = "https://github.com/AdrianJunge/adrianjunge.de".freeze
  BUG_BOUNTY_COUNT = 7
  # Update when editing profile copy, identity, or undated About information. These are
  # editorial dates, never deployment or checkout timestamps.
  MODIFIED = "2026-10-28".freeze
  # Update when editing visible landing-page copy.
  LANDING_MODIFIED = "2026-10-28".freeze
  DESCRIPTION = "Security research, CVEs, bug bounties, CTF writeups, and technical notes by #{NAME}.".freeze
  LANDING_LEAD = "CTF player and computer science student creating writeups, collecting bounties and CVEs. Sometimes I lose myself in algorithmic challenges.".freeze
  LANDING_TAGLINE = "Teaching machines to misbehave.".freeze
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
  def encoded_email = [ email ].pack("m0")
  def readable_email = email.gsub("@", " [at] ").gsub(".", " [dot] ")
  def pgp_path = PGP_PATH
  def source_url = SOURCE_URL
  def bug_bounty_count = BUG_BOUNTY_COUNT
  def modified = MODIFIED
  def landing_modified = LANDING_MODIFIED
  def description = DESCRIPTION
  def landing_lead = LANDING_LEAD
  def landing_tagline = LANDING_TAGLINE
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
