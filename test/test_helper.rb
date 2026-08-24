ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test", "support", "**", "*.rb")].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def parse_content_json(path)
      ::JSON.parse(File.read(path), allow_comments: true)
    end

    def asset_path_prefix
      Rails.application.config.assets.prefix
    end

    include ContentTestHelpers
  end
end
