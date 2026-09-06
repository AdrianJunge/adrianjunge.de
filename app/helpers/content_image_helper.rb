require "json"

# The generated manifest is an authoring artifact, not a published asset. Keep
# logical names here; Rails resolves their release-specific fingerprints later.
module ContentImageHelper
  def self.manifest_path
    Rails.root.join("config/image_variants.json")
  end

  def self.manifest_version
    return "missing" unless manifest_path.file?

    stat = manifest_path.stat
    [ stat.size, stat.mtime.to_r, stat.ctime.to_r ].join(":")
  end

  def self.manifest
    return {} unless manifest_path.file?

    ContentSnapshot.fetch(manifest_path, kind: :image_manifest) { |json| JSON.parse(json) }
  end

  def self.image_attributes(path, sizes: nil)
    descriptor = manifest[path.to_s]
    return { src: path.to_s } unless descriptor

    attributes = { src: descriptor.fetch("src"), width: descriptor.fetch("width"), height: descriptor.fetch("height") }
    variants = descriptor["variants"]
    if variants.present?
      attributes[:srcset] = variants.map { |variant| "#{variant.fetch('path')} #{variant.fetch('width')}w" }.join(", ")
      attributes[:sizes] = sizes || "(max-width: 767px) 88px, 160px"
    end
    attributes
  end

  def content_image_tag(path, **options)
    attributes = ContentImageHelper.image_attributes(path, sizes: options.delete(:sizes))
    source = attributes.delete(:src)
    if attributes[:srcset]
      attributes[:srcset] = attributes[:srcset].split(", ").map do |candidate|
        logical_path, width = candidate.split(" ", 2)
        "#{asset_path(logical_path)} #{width}"
      end.join(", ")
    end
    image_tag(source, { loading: "lazy", decoding: "async" }.merge(attributes).merge(options))
  end
end
