require "application_system_test_case"
require_relative "../support/site_page_helpers"

class TerminalTest < ApplicationSystemTestCase
  include SitePageHelpers

  test "terminal cd command accepts listed labels" do
    event = first_ctf_event_with_writeups

    page.current_window.resize_to(1280, 900)
    visit "/"

    find("#terminal-taskbar-button").click
    assert_selector "#terminal-container:not(.terminal-minimized)"
    assert_selector ".xterm-rows", text: "about"

    find(".xterm-helper-textarea", visible: :all).send_keys("cd ctf", :enter)
    assert_current_path "/ctf"

    assert_selector "#terminal-container:not(.terminal-minimized)"
    assert_selector ".xterm-rows", text: "adrian@my-space:/ctf$"
    assert_selector ".xterm-rows", text: event[:directory]

    find(".xterm-helper-textarea", visible: :all).send_keys("cd #{event[:directory]}", :enter)
    assert_current_path event[:link]
  end

  test "terminal stays bounded and padded across viewport sizes" do
    [
      { width: 720, height: 844 },
      { width: 1024, height: 768 },
      { width: 2560, height: 1440 }
    ].each do |viewport|
      page.current_window.resize_to(viewport[:width], viewport[:height])
      visit "/"
      page.execute_script("localStorage.setItem('terminal-open', 'false')")
      visit "/"

      page.execute_script(<<~JS)
        const terminal = document.getElementById('terminal-container');
        terminal.style.transition = 'none';
        // Keep page scrolling testable even when the compact homepage fits a tall viewport.
        document.body.style.minHeight = `${window.innerHeight * 2}px`;
        const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
        window.scrollTo(0, Math.min(420, Math.max(0, maxScroll)));
      JS
      page.execute_script("document.getElementById('terminal-taskbar-button').click()")
      assert_selector ".xterm"
      assert_selector ".xterm-viewport"

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const terminal = document.querySelector("#terminal-container");
          const button = document.querySelector(".terminal-button");
          const xterm = terminal.querySelector(".xterm");
          const viewport = terminal.querySelector(".xterm-viewport");
          const terminalRect = terminal.getBoundingClientRect();
          const buttonRect = button.getBoundingClientRect();
          const viewportRect = viewport.getBoundingClientRect();
          const terminalStyle = window.getComputedStyle(terminal);
          const xtermStyle = window.getComputedStyle(xterm);
          const viewportStyle = window.getComputedStyle(viewport);
          const bodyStyle = window.getComputedStyle(document.body);
          const openingScrollY = window.scrollY;
          const currentScrollY = window.scrollY;

          window.scrollTo(1000, currentScrollY);
          const horizontalScrollAfterAttempt = window.scrollX;
          window.scrollTo(0, currentScrollY + 120);
          const outsideScrollDelta = window.scrollY - currentScrollY;
          window.scrollTo(0, currentScrollY);

          let terminalWheelReachedPage = false;
          let outsideWheelReachedPage = false;
          const terminalWheelPageListener = () => { terminalWheelReachedPage = true; };
          document.body.addEventListener("wheel", terminalWheelPageListener);
          terminal.dispatchEvent(new WheelEvent("wheel", { bubbles: true, deltaY: 120 }));
          document.body.removeEventListener("wheel", terminalWheelPageListener);
          document.body.addEventListener("wheel", () => { outsideWheelReachedPage = true; }, { once: true });
          document.body.dispatchEvent(new WheelEvent("wheel", { bubbles: true, deltaY: 120 }));

          return {
            width: Math.round(terminalRect.width),
            height: Math.round(terminalRect.height),
            maxWidth: terminalStyle.width,
            buttonWidth: Math.round(buttonRect.width),
            fontSize: parseFloat(xtermStyle.fontSize),
            terminalLeft: Math.round(terminalRect.left),
            terminalRight: Math.round(terminalRect.right),
            viewportWidth: Math.round(window.innerWidth),
            contentInsetLeft: Math.round(viewportRect.left - terminalRect.left),
            contentInsetTop: Math.round(viewportRect.top - terminalRect.top),
            horizontalScrollAfterAttempt,
            openingScrollY,
            outsideScrollDelta,
            terminalWheelReachedPage,
            outsideWheelReachedPage,
            bodyScrollLocked: document.body.classList.contains("terminal-scroll-locked"),
            htmlScrollLocked: document.documentElement.classList.contains("terminal-scroll-locked"),
            bodyPosition: bodyStyle.position,
            bodyTop: document.body.style.top,
            viewportOverflowY: viewportStyle.overflowY,
            terminalHorizontalOverflow: terminal.scrollWidth - terminal.clientWidth,
            viewportHorizontalOverflow: viewport.scrollWidth - viewport.clientWidth
          };
        })()
      JS

      assert_operator metrics["width"], :<=, 1320
      assert_operator metrics["height"], :<=, 750
      assert_operator metrics["buttonWidth"], :<=, 48
      assert_operator metrics["fontSize"], :>=, 13
      assert_operator metrics["fontSize"], :<=, 18
      assert_operator metrics["terminalLeft"], :>=, 0
      assert_operator metrics["terminalRight"], :<=, metrics["viewportWidth"]
      assert_operator metrics["contentInsetLeft"], :>=, 12
      assert_operator metrics["contentInsetTop"], :>=, 48
      assert_operator metrics["horizontalScrollAfterAttempt"], :<=, 1
      assert_operator metrics["openingScrollY"], :>=, 0
      assert_operator metrics["outsideScrollDelta"], :>, 0
      assert_equal false, metrics["terminalWheelReachedPage"]
      assert_equal true, metrics["outsideWheelReachedPage"]
      assert_equal false, metrics["bodyScrollLocked"]
      assert_equal false, metrics["htmlScrollLocked"]
      assert_not_equal "fixed", metrics["bodyPosition"]
      assert_equal "", metrics["bodyTop"]
      assert_equal "scroll", metrics["viewportOverflowY"]
      assert_operator metrics["terminalHorizontalOverflow"], :<=, 1
      assert_operator metrics["viewportHorizontalOverflow"], :<=, 1
    end
  end
end
