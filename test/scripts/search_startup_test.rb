require "test_helper"
require "open3"

class SearchStartupTest < ActiveSupport::TestCase
  test "concurrent first searches can index PHP before any render cache is populated" do
    script = <<~'RUBY'
      require "rouge"
      # Make dictionary loading yield, as it can during a cold filesystem read.
      Rouge::Lexers::PHP.send(:lazy_procs).unshift(proc { sleep 0.1 })
      require_relative "config/environment"
      gate = Queue.new
      threads = Array.new(4) do
        Thread.new do
          gate.pop
          Rails.application.executor.wrap { SiteSearch.new.search("ecsc").pluck(:url) }
        end
      end
      threads.each { gate << true }
      abort "Incorrect concurrent search results" unless threads.map(&:value).all? { |urls| urls == [ "/ctf#ctf-event-cscg" ] }
    RUBY
    output, error, status = Open3.capture3({ "RAILS_ENV" => "test" }, RbConfig.ruby, "-e", script, chdir: Rails.root)
    assert status.success?, "Concurrent cold searches failed:\n#{output}\n#{error}"
  end
end
