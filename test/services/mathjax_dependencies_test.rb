require "test_helper"

class MathjaxDependenciesTest < ActiveSupport::TestCase
  test "CDN URLs use the dependency inventory and its locked versions" do
    directory = Rails.root.join("config/mathjax")
    dependencies = JSON.parse(directory.join("package.json").read).fetch("dependencies")
    packages = JSON.parse(directory.join("package-lock.json").read).fetch("packages")

    dependencies.each do |name, version|
      assert_match(/\A\d+\.\d+\.\d+\z/, version)
      assert_equal version, packages.fetch("").fetch("dependencies").fetch(name)
      assert_equal version, packages.fetch("node_modules/#{name}").fetch("version")
      assert_equal version, MathjaxDependencies.version(name)
    end

    assert_equal "#{MathjaxDependencies::CDN}/mathjax@#{dependencies.fetch('mathjax')}/tex-chtml.js", MathjaxDependencies.component_url
    assert_equal "#{MathjaxDependencies::CDN}/@mathjax/mathjax-newcm-font@#{dependencies.fetch('@mathjax/mathjax-newcm-font')}", MathjaxDependencies.font_url
    assert_equal "#{MathjaxDependencies::CDN}/@mathjax/%%FONT%%-font@#{dependencies.fetch('@mathjax/mathjax-newcm-font')}", MathjaxDependencies.font_path
  end
end
