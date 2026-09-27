require "json"

# This npm inventory is updated by Dependabot and is the source of CDN versions.
# No Node process or npm installation is required by the running Rails app.
class MathjaxDependencies
  CDN = "https://cdn.jsdelivr.net/npm".freeze
  VERSIONS = JSON.parse(Rails.root.join("config/mathjax/package.json").read).fetch("dependencies").freeze

  def self.version(package)
    value = VERSIONS.fetch(package)
    raise ArgumentError, "MathJax CDN dependencies require exact release versions" unless value.match?(/\A\d+\.\d+\.\d+\z/)

    value
  end

  def self.component_url
    "#{CDN}/mathjax@#{version('mathjax')}/tex-chtml.js"
  end

  def self.font_url
    "#{CDN}/@mathjax/mathjax-newcm-font@#{version('@mathjax/mathjax-newcm-font')}"
  end

  def self.font_path
    "#{CDN}/@mathjax/%%FONT%%-font@#{version('@mathjax/mathjax-newcm-font')}"
  end
end
