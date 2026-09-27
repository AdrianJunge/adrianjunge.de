require "digest"

# Cache only deterministic content records. Source revisions include the file
# inventory and canonical targets, so edits, deletions and replacements refresh
# the catalog without a process restart. Callers always receive their own copy.
class ContentCatalog
  CACHE = ActiveSupport::Cache::MemoryStore.new(size: 8.megabytes, coder: nil)
  VERSION = "1".freeze

  def self.fetch(key, revision:)
    cached = CACHE.fetch([ VERSION, revision, Time.zone&.name, key ]) do
      ContentSnapshot.deep_freeze(copy_record(yield))
    end
    copy_record(cached)
  end

  # ActiveSupport's generic deep_dup shares TimeWithZone's internal Time
  # objects. Reconstruct dates so caller mutations cannot affect the cache.
  def self.copy_record(value)
    case value
    when Hash
      value.to_h { |key, item| [ copy_record(key), copy_record(item) ] }
    when Array
      value.map { |item| copy_record(item) }
    when ActiveSupport::TimeWithZone
      value.utc.dup.in_time_zone(value.time_zone)
    else
      value.deep_dup
    end
  end
  private_class_method :copy_record

  def self.revision(paths)
    signatures = paths.map(&:to_s).uniq.sort.map do |path|
      stat = File.stat(path)
      [ path, File.realpath(path), stat.dev, stat.ino, stat.size, stat.mtime.to_r, stat.ctime.to_r ]
    rescue SystemCallError => error
      # Discovery may include inaccessible or unresolved optional entries, which
      # TrustedContentPath also skips. Required loaders still report failures.
      [ path, :unavailable, error.class.name ]
    end
    Digest::SHA256.hexdigest(Marshal.dump(signatures))
  end

  def self.clear
    CACHE.clear
  end
end
