require "test_helper"
require "open3"

class TestEnvironmentTest < ActiveSupport::TestCase
  test "test boot initializes a usable secret without credentials or a shared secret file" do
    script = <<~RUBY
      require_relative "config/application"

      Rails::Application::Configuration.prepend(Module.new do
        private

        def generate_local_secret
          raise "Test boot must not read or write the shared local secret file"
        end
      end)

      Rails.application.define_singleton_method(:credentials) do
        raise "Test boot must not depend on deployment credentials"
      end

      require_relative "config/environment"
      secret = Rails.application.secret_key_base
      abort "Test secret is missing or too short" unless secret.is_a?(String) && secret.length >= 64
      verifier = Rails.application.message_verifier("test-boot")
      abort "Test secret cannot sign messages" unless verifier.verify(verifier.generate("ready")) == "ready"
    RUBY

    output, error, status = Open3.capture3(
      { "RAILS_ENV" => "test", "CI" => "true", "SECRET_KEY_BASE" => nil, "SECRET_KEY_BASE_DUMMY" => nil, "RAILS_MASTER_KEY" => nil },
      RbConfig.ruby, "-e", script, chdir: Rails.root
    )
    assert status.success?, "Test environment boot failed:\n#{output}\n#{error}"
  end
end
