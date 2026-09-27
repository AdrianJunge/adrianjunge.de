class ContentIconRegistry
  ICONS = {
    "blog" => "task-bar/blog.svg", "cve" => "other/cve.svg", "bug-bounty" => "other/bug-bounty.svg",
    "certificate" => "other/certificate.svg", "talk" => "other/talk-slides.png",
    "achievement" => "other/achievement.svg", "challenge" => "ctf/kitctf.png"
  }.freeze

  def self.for(kind, title: nil)
    ICONS.fetch(kind.to_s) do
      case title.to_s.downcase
      when /\btalk\b|intro/ then ICONS.fetch("talk")
      when /certif|cpts/ then ICONS.fetch("certificate")
      else ICONS.fetch("achievement")
      end
    end
  end
end
