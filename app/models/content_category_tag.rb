module ContentCategoryTag
  CATEGORY_KEYS = {
    "web" => "web",
    "web exploitation" => "web",
    "pwn" => "pwn",
    "pwnable" => "pwn",
    "binary exploitation" => "pwn",
    "crypto" => "crypto",
    "cryptography" => "crypto",
    "reverse" => "reverse",
    "reversing" => "reverse",
    "rev" => "reverse",
    "misc" => "misc",
    "forensics" => "forensics",
    "osint" => "osint",
    "blockchain" => "blockchain",
    "web3" => "blockchain",
    ".net" => "dotnet",
    "dotnet" => "dotnet",
    "privilege escalation" => "privesc"
  }.freeze

  module_function

  def css_key(value)
    CATEGORY_KEYS[normalized(value)] || "other"
  end

  def recognized?(value)
    CATEGORY_KEYS.key?(normalized(value))
  end

  def normalized(value)
    value.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
