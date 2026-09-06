require "digest"

# Bounded process-local input snapshots. Mutable per-request view records are
# constructed from these immutable documents, so consumers cannot change a
# later response. Stat checks preserve development reloads and atomic deploys.
class ContentSnapshot
  LIMIT = 256
  @entries = {}
  @mutex = Mutex.new

  class << self
    def fetch(path, kind: :text)
      path = Pathname(path)
      return yield("") unless path.file?

      @mutex.synchronize do
        stat = path.stat
        version = [ stat.dev, stat.ino, stat.size, stat.mtime, stat.ctime, path.realpath.to_s ]
        key = [ path.to_s, kind ]
        cached = @entries[key]
        if cached && cached[:version] == version
          @entries.delete(key)
          @entries[key] = cached
          return cached[:value]
        end

        value = deep_freeze(yield(File.read(path)))
        @entries.delete(key)
        @entries.shift while @entries.size >= LIMIT
        @entries[key] = { version: version.freeze, value: value }.freeze
        value
      end
    end

    def clear
      @mutex.synchronize { @entries.clear }
    end

    def size
      @mutex.synchronize { @entries.size }
    end

    def deep_freeze(value)
      case value
      when Hash
        value.each { |key, item| deep_freeze(key); deep_freeze(item) }
      when Array
        value.each { |item| deep_freeze(item) }
      end
      value.freeze
    end
  end
end
