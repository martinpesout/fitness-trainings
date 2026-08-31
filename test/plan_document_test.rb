# frozen_string_literal: true

require_relative "test_helper"
require "training_system/plan_document"

class PlanDocumentTest < Minitest::Test
  def with_plan(contents)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "plan.md")
      File.write(path, contents)
      yield path
    end
  end

  def test_parses_front_matter_and_headings
    with_plan("---\nstatus: draft\nweek: 1\n---\n# Plan\n\n## Session A\n") do |path|
      document = TrainingSystem::PlanDocument.new(path)

      assert_equal({ "status" => "draft", "week" => 1 }, document.metadata)
      assert_equal ["Plan", "Session A"], document.headings
      assert_equal ["Session B"], document.require_headings(["Plan", "Session B"])
    end
  end

  def test_rejects_missing_front_matter_with_source_path
    with_plan("# Plan\n") do |path|
      error = assert_raises(TrainingSystem::DataError) { TrainingSystem::PlanDocument.new(path) }

      assert_includes error.message, path
    end
  end

  def test_plan_template_exposes_the_block_contract
    path = File.expand_path("../_system/templates/plan.md", __dir__)
    document = TrainingSystem::PlanDocument.new(path)
    contents = File.read(path)

    assert_equal 3, document.metadata.fetch("weekly_strength_frequency")
    assert_nil document.metadata.fetch("planned_duration_weeks")
    assert_nil document.metadata.fetch("target_strength_sessions")
    assert_empty document.require_headings([
      "Block Intent",
      "Lifecycle",
      "Duration and Session Target",
      "Shared Rules",
      "Session Templates",
      "Progression",
      "Optional Cardio",
      "Integrated Conditioning",
      "Approved Changes"
    ])
    assert_includes contents, "draft -> approved -> active -> completed"
    assert_includes contents, "duration_contract: 3..6"
    assert_includes contents, "target_strength_sessions = planned_duration_weeks * weekly_strength_frequency"
    assert_includes contents, "Optional cardio does not count toward strength-block adherence"
    assert_includes contents, "Integrated conditioning is part of a session"
  end
end
