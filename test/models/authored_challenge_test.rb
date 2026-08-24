require "test_helper"

class AuthoredChallengeTest < ActiveSupport::TestCase
  test "normalizes authored challenge metadata from optional section" do
    metadata = {
      "optional" => {
        "authored_challenge" => {
          "event" => "FixtureCTF 2099",
          "event_url" => "https://fixture.invalid/event",
          "summary" => "Hybrid web and pwn challenge."
        }
      }
    }

    assert_equal(
      {
        label: "Authored challenge",
        event: "FixtureCTF 2099",
        event_url: "https://fixture.invalid/event",
        summary: "Hybrid web and pwn challenge.",
        date: nil,
        id: nil
      },
      AuthoredChallenge.from_metadata(metadata)
    )
    assert_equal "Authored challenge", AuthoredChallenge.filter_label_for(metadata)
  end

  test "ignores omitted authored challenge metadata" do
    assert_nil AuthoredChallenge.from_metadata({ "optional" => {} })
    assert_nil AuthoredChallenge.filter_label_for({})
  end

  test "boolean authored challenge metadata uses fallback details" do
    assert_equal(
      {
        label: "Authored challenge",
        event: nil,
        event_url: nil,
        summary: nil,
        date: nil,
        id: nil
      },
      AuthoredChallenge.from_metadata({ "optional" => { "authored_challenge" => true } })
    )
  end

  test "sorts recognition filters before normal tags" do
    values = [ "web", AuthoredChallenge::FILTER_LABEL, "crypto", WriteupWinner::FILTER_LABEL ]

    assert_equal(
      [ WriteupWinner::FILTER_LABEL, AuthoredChallenge::FILTER_LABEL, "crypto", "web" ],
      values.sort_by { |value| AuthoredChallenge.filter_sort_key(value) }
    )
  end
end
