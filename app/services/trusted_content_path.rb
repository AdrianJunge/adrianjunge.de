class TrustedContentPath
  def self.file(root:, candidate:)
    canonical_root = Pathname(root).realpath
    canonical_file = Pathname(candidate).realpath

    return unless canonical_file.ascend.any? { |ancestor| ancestor == canonical_root }
    return unless canonical_file.file?

    canonical_file
  rescue SystemCallError, ArgumentError
    nil
  end
end
