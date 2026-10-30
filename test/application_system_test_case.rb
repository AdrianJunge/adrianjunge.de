require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  DEFAULT_SCREEN_SIZE = [ 1400, 1400 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: DEFAULT_SCREEN_SIZE

  setup do
    # Selenium reuses its window between tests, including its last viewport size.
    page.current_window.resize_to(*DEFAULT_SCREEN_SIZE)
  end
end
