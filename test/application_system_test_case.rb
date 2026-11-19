require "test_helper"

module ChromeStorageReset
  def reset!
    return super unless @browser

    # Chrome 158 requires a URL origin where Capybara 3.40 passes "*".
    @storage_origin = current_url[%r{\Ahttps?://[^/]+}]
    super
  ensure
    @storage_origin = nil
  end

  private

  def execute_cdp(command, params = {})
    if command == "Storage.clearDataForOrigin" && params[:origin] == "*"
      return super("Network.clearBrowserCookies") unless @storage_origin

      params = params.merge(origin: @storage_origin)
    end
    super(command, params)
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeStorageReset)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  DEFAULT_SCREEN_SIZE = [ 1400, 1400 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: DEFAULT_SCREEN_SIZE

  setup do
    page.current_window.resize_to(*DEFAULT_SCREEN_SIZE)
  end
end
