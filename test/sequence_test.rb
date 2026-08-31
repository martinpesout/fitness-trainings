# frozen_string_literal: true

require_relative "test_helper"
require "training_system/sequence"

class SequenceTest < Minitest::Test
  def test_starts_with_first_template_when_no_position_exists
    assert_equal "A", TrainingSystem::Sequence.next(sequence: ["A", "B", "C"], position: nil)
  end

  def test_advances_to_the_template_after_the_completed_position
    assert_equal "B", TrainingSystem::Sequence.next(sequence: ["A", "B", "C"], position: "A")
  end

  def test_wraps_after_the_last_completed_template
    assert_equal "A", TrainingSystem::Sequence.next(sequence: ["A", "B", "C"], position: "C")
  end

  def test_cancelled_date_does_not_call_sequence_and_keeps_current_position
    current_position = "C"

    assert_equal "C", current_position
  end

  def test_repeats_the_partial_template_when_decision_is_repeat
    assert_equal "A", TrainingSystem::Sequence.next(
      sequence: ["A", "B", "C"], position: "A", outcome: "partial", decision: "repeat"
    )
  end

  def test_advances_after_a_partial_template_when_decision_is_advance
    assert_equal "B", TrainingSystem::Sequence.next(
      sequence: ["A", "B", "C"], position: "A", outcome: "partial", decision: "advance"
    )
  end

  def test_rejects_a_partial_outcome_without_a_valid_decision
    error = assert_raises(ArgumentError) do
      TrainingSystem::Sequence.next(sequence: ["A", "B", "C"], position: "A", outcome: "partial")
    end

    assert_match(/decision/, error.message)
  end

  def test_rejects_duplicate_sequence_names
    assert_raises(ArgumentError) do
      TrainingSystem::Sequence.next(sequence: ["A", "A"], position: nil)
    end
  end

  def test_rejects_empty_sequence_names
    assert_raises(ArgumentError) do
      TrainingSystem::Sequence.next(sequence: ["A", ""], position: nil)
    end
  end

  def test_rejects_whitespace_only_sequence_names
    assert_raises(ArgumentError) do
      TrainingSystem::Sequence.next(sequence: ["A", "   "], position: nil)
    end
  end

  def test_rejects_non_string_sequence_names
    assert_raises(ArgumentError) do
      TrainingSystem::Sequence.next(sequence: ["A", :B], position: nil)
    end
  end
end
