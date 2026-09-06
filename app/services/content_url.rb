require "uri"

module ContentUrl
  module_function

  # Metadata links are either same-site absolute paths/fragments or ordinary
  # HTTP(S) destinations. Article Markdown is separately trusted author input.
  def valid?(value)
    raw = value.to_s
    return false if raw.blank? || raw.match?(/[\s\\\x00-\x1f]/)
    return true if raw.start_with?("#") && raw.length > 1
    return true if raw.start_with?("/") && !raw.start_with?("//")

    uri = URI.parse(raw)
    %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    false
  end
end
