require "application_system_test_case"

class TagConsistencyTest < ApplicationSystemTestCase
  test "record badges share typography and centered chevrons across About and timeline" do
    entry = production_content_repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).first

    [ 390, 1440 ].each do |width|
      page.current_window.resize_to(width, 1000)
      visit about_path
      find("#cves > summary").click
      about_card = find("##{entry.fetch('id')}")
      about_metrics = record_badge_metrics(about_card)

      visit timeline_path
      timeline_card = find(".timeline-card-hitbox[href='/about##{entry.fetch('id')}']", visible: :all).find(:xpath, "..")
      timeline_metrics = record_badge_metrics(timeline_card)

      assert_equal about_metrics, timeline_metrics, "Record badge styles differ at #{width}px"
      about_metrics.each_value do |metrics|
        assert_equal 1, metrics.fetch("chevrons")
        assert_equal "none", metrics.fetch("pseudoArrow")
        assert_operator metrics.fetch("labelOffset"), :<, 1
        assert_operator metrics.fetch("chevronOffset"), :<, 1
      end
    end
  end

  private

  def record_badge_metrics(card)
    card.evaluate_script(<<~JS)
      (element => Object.fromEntries(["cve", "cwe"].map(kind => {
        const badge = element.querySelector(`.${kind}-badge`);
        const label = badge.querySelector(".content-tag-label");
        const chevron = badge.querySelector(".content-tag-chevron");
        const style = getComputedStyle(badge);
        const midpoint = node => { const rect = node.getBoundingClientRect(); return rect.top + rect.height / 2; };
        return [kind, {
          fontSize: style.fontSize, fontWeight: style.fontWeight,
          lineHeight: style.lineHeight, padding: style.padding,
          borderRadius: style.borderRadius, height: badge.getBoundingClientRect().height,
          chevrons: badge.querySelectorAll(".content-tag-chevron").length,
          pseudoArrow: getComputedStyle(badge, "::after").content,
          labelOffset: Math.round(Math.abs(midpoint(label) - midpoint(badge)) * 100) / 100,
          chevronOffset: Math.round(Math.abs(midpoint(chevron) - midpoint(badge)) * 100) / 100
        }];
      })))(this)
    JS
  end
end
