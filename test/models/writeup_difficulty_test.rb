require "test_helper"

class WriteupDifficultyTest < ActiveSupport::TestCase
  test "normalizes supported difficulty labels" do
    assert_equal({ key: "intro", label: "Intro" }, WriteupDifficulty.from_metadata("difficulty" => "Intro"))
    assert_equal({ key: "easy", label: "Easy" }, WriteupDifficulty.from_metadata("difficulty" => "Easy"))
    assert_equal({ key: "medium", label: "Medium" }, WriteupDifficulty.from_metadata("difficulty" => "Normal"))
    assert_equal({ key: "hard", label: "Hard" }, WriteupDifficulty.from_metadata("difficulty" => "Hard"))
    assert_equal({ key: "insane", label: "Insane / 0-day" }, WriteupDifficulty.from_metadata("difficulty" => "0-day"))
  end

  test "falls back to unknown difficulty when omitted or unsupported" do
    assert_equal({ key: "unknown", label: "unknown difficulty" }, WriteupDifficulty.from_metadata({}))
    assert_equal({ key: "unknown", label: "unknown difficulty" }, WriteupDifficulty.from_metadata("difficulty" => "not listed"))
    assert_nil WriteupDifficulty.filter_label_for({})
    assert_equal "unknown difficulty", WriteupDifficulty.filter_label_for("difficulty" => "not listed")
  end

  test "reads difficulty from optional metadata section" do
    metadata = {
      "optional" => {
        "difficulty" => {
          "label" => "Medium"
        }
      }
    }

    assert_equal({ key: "medium", label: "Medium" }, WriteupDifficulty.from_metadata(metadata))
  end

  test "identifies and sorts filter labels by difficulty order" do
    labels = [ "Hard", "unknown difficulty", "Easy", "Insane / 0-day", "Intro", "Medium" ]

    assert WriteupDifficulty.filter_label?("Hard")
    assert WriteupDifficulty.filter_label?("unknown difficulty")
    assert_not WriteupDifficulty.filter_label?("Web")
    assert_equal [ "Intro", "Easy", "Medium", "Hard", "Insane / 0-day", "unknown difficulty" ],
                 labels.sort_by { |label| WriteupDifficulty.filter_sort_key(label) }
  end
end
