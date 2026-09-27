require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Website
  class Application < Rails::Application
    config.load_defaults 8.0

    config.autoload_lib(ignore: %w[tasks])
    config.exceptions_app = routes

    # Run after engines register their default directories: Propshaft publishes
    # every file on the load path, including Markdown/JSON if left unfiltered.
    initializer "website.public_asset_paths", after: "propshaft.append_assets_path", before: "propshaft.assets_middleware" do |app|
      app.config.assets.paths = %w[
        app/assets/builds app/assets/images app/javascript
      ].map { |path| root.join(path) }
    end

    config.after_initialize do |app|
      app.config.assets.paths.uniq!
    end
  end
end
