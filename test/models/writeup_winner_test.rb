require "test_helper"

class WriteupWinnerTest < ActiveSupport::TestCase
  test "normalizes hash metadata with proof url" do
    metadata = {
      "writeup_winner" => {
        "label" => "Best web writeup",
        "proof_url" => "https://example.com/proof"
      }
    }

    assert_equal(
      { label: "Best web writeup", proof_url: "https://example.com/proof" },
      WriteupWinner.from_metadata(metadata)
    )
    assert_equal "Writeup winner", WriteupWinner.filter_label_for(metadata)
  end

  test "ignores winner metadata without proof url" do
    metadata = { "writeup_winner" => { "label" => "Best web writeup" } }

    assert_nil WriteupWinner.from_metadata(metadata)
    assert_nil WriteupWinner.filter_label_for(metadata)
  end

  test "sorts generic winner filter before normal tags" do
    values = [ "web", "crypto", WriteupWinner::FILTER_LABEL ]

    assert_equal(
      [ WriteupWinner::FILTER_LABEL, "crypto", "web" ],
      values.sort_by { |value| WriteupWinner.filter_sort_key(value) }
    )
  end
end
