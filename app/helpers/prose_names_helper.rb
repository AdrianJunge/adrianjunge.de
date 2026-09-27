module ProseNamesHelper
  # Editorial names used in descriptive copy and collection-card excerpts.
  # Keep matching explicit: capitalization alone also catches ordinary prose.
  PROPER_NAMES = [
    ".;,;.", "1&1 Mail & Media", "ACM Cyber", "ASP .NET Core", "ASP.NET Core", "Active Directory",
    "Adrian Junge", "Alice", "BSides Munich", "Bob", "CSCG", "CORS Playground",
    "Chaos Computer Club", "ChurchCRM", "Climbing Stairs", "Cyber Security Challenges Germany",
    "DHM", "DVCTF", "DaVinciCode", "Deutsche Hacking Meisterschaft", "Docker",
    "Docker-compose", "Doctor Doom", "ECSC", "EHAX", "FCSC", "FFmpeg",
    "FZI", "FZI Forschungszentrum für Informatik", "Fantastic 4", "Fibonacci",
    "Firedancer", "Flask", "FluxFingers", "FluxKITtens", "Forschungszentrum für Informatik",
    "France", "Fraunhofer IOSB", "GLIBC", "GPN", "GPNCTF", "Germany", "GitHub", "GlacierCTF", "Google CTF",
    "HTB CPTS", "Hack The Box Certified Penetration Testing Specialist", "Hackceler8",
    "Immunefi", "India", "IntroCTF", "Invictus DTU", "Italy", "Java", "Joomla",
    "Joomla CMS", "Joomla Security Strike Team", "KIT", "KIT Karlsruhe Institute of Technology", "KITCTF", "Karlsruhe",
    "Karlsruhe Institute of Technology", "Konoha", "LACTF", "Latveria", "LeetCode",
    "Linux", "Louvre", "Louvre Museum", "MaltaCTF", "Mexico",
    "Ministry of Information and Communications Technology of Konoha", "MySQL", "NIST",
    "OWASP Stammtisch Karlsruhe", "PROJECT SEKAI", "Pascal", "SEKAICTF", "SMILEYCTF",
    "STEVE", "Screenpresso", "SekaiCTF", "Shorten", "SmileyCTF", "SnakeCTF", "SuiteCRM",
    "SwampCTF", "UCLA", "UMDCTF", "University of Maryland", "VulnCheck", "WordPress",
    "XCTF", "Zlib", "chaos computer club", "vurlo",
    "École supérieure d'ingénieurs Léonard-de-Vinci"
  ].map(&:freeze).freeze

  PROPER_NAME_PATTERN = /(?<![\p{L}\p{M}\p{N}_])#{Regexp.union(PROPER_NAMES.sort_by { |name| -name.length })}(?![\p{L}\p{M}\p{N}_])/.freeze

  # Accept plain text only. Every unmatched fragment and matched name is
  # escaped by the view helpers; existing HTML is displayed as literal text.
  def italicize_proper_names(text)
    text = String.new(text.to_s)
    fragments = []
    offset = 0

    text.scan(PROPER_NAME_PATTERN) do
      match = Regexp.last_match
      fragments << text[offset...match.begin(0)]
      offset = match.end(0)
      fragments << content_tag(:i, match[0], class: "proper-name")
    end
    fragments << text[offset..]

    safe_join(fragments)
  end
end
