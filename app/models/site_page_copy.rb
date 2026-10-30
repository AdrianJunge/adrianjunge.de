module SitePageCopy
  DESCRIPTIONS = {
    blog: "Thoughts I want to share on security work and learnings.",
    ctf: "Capture The Flag writeups grouped by competition events.",
    timeline: "Security research, CTF writeups, blog posts, CVEs, bug bounties, authored challenges, certificates, talks, and achievements ordered by date."
  }.transform_values(&:freeze).freeze

  def self.description(page)
    DESCRIPTIONS.fetch(page.to_sym)
  end
end
