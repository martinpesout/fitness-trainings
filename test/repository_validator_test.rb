# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "fileutils"

begin
  require "training_system/repository_validator"
  REPOSITORY_VALIDATOR_LOAD_ERROR = nil
rescue LoadError => error
  REPOSITORY_VALIDATOR_LOAD_ERROR = error
end

class RepositoryValidatorTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  REQUIRED_HEADINGS = [
    "Block Intent", "Lifecycle", "Duration and Session Target", "Shared Rules",
    "Session Templates", "Progression", "Optional Cardio", "Integrated Conditioning",
    "Approved Changes"
  ].freeze
  REQUIRED_REVIEW_HEADINGS = [
    "Adherence", "RPE and Progress", "Novelty", "Fatigue and Pain", "Cardio",
    "Next-Block Recommendation"
  ].freeze

  def with_repository
    Dir.mktmpdir("training-system") do |root|
      write_canonical_root(root)
      yield root
    end
  end

  def write_canonical_root(root)
    write(root, "data/profile.yaml", <<~YAML)
      goals: { primary: [] }
      training: { weekly_strength_frequency: 3 }
      health: { review_status: needs_review, limitations: [] }
    YAML
    write(root, "data/equipment.yaml", "review_status: needs_input\nitems: []\nnotes: null\n")
    %w[preferences.md exercise_library.yaml coaching_rules.md history_summary.md].each do |path|
      write(root, "data/#{path}", path.end_with?(".yaml") ? "exercises: []\n" : "# #{path}\n")
    end
    write(root, "calendar/exceptions.yaml", "exceptions: []\n")
    write(root, "_system/state/current.yaml", <<~YAML)
      active_block: null
      plan_status: null
      default_sequence: [A, B, C]
      sequence_position: null
      next_session: A
      block_number: 0
    YAML
    %w[plan.md session-log.md block-review.md].each { |path| write(root, "_system/templates/#{path}", "# #{path}\n") }
  end

  def write_active_plan(root, name: "2026-09-block-001", metadata: {}, headings: REQUIRED_HEADINGS, include_template_headings: true)
    fields = {
      "status" => "approved", "block_number" => 1, "planned_duration_weeks" => 4,
      "weekly_strength_frequency" => 3, "target_strength_sessions" => 12,
      "sequence" => %w[A B C]
    }.merge(metadata)
    front_matter = fields.map { |key, value| "#{key}: #{yaml_value(value)}" }.join("\n")
    all_headings = headings
    all_headings += fields.fetch("sequence").map { |template| "Template #{template}" } if include_template_headings
    sections = all_headings.map do |heading|
      body = if heading.start_with?("Template ")
        <<~MARKDOWN.chomp
          | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
          | --- | --- | --- | --- | --- |
          | Goblet squat | 3 | 8-10 | 7 | Controlled tempo |
        MARKDOWN
      elsif heading == "Integrated Conditioning"
        <<~MARKDOWN.chomp
          - Session template: none
          - Minutes and intensity: none
          - Total-duration impact: none
          - Strength-volume impact: none
          - Lower-body impact: none
          - Rationale: none planned
        MARKDOWN
      else
        "Contract content."
      end
      "## #{heading}\n\n#{body}"
    end
    write(root, "blocks/#{name}/plan.md", "---\n#{front_matter}\n---\n\n#{sections.join("\n\n")}\n")
  end

  def write_session_log(root, block: "2026-09-block-001", filename: "01-A.md", metadata: {})
    fields = {
      "date" => "2026-09-01", "block_number" => 1, "session_number" => 1,
      "template" => "A", "status" => "completed", "sequence_position_before" => nil,
      "sequence_decision" => nil, "next_session" => "B", "credited_strength_session" => true
    }.merge(metadata)
    front_matter = fields.map { |key, value| "#{key}: #{yaml_value(value)}" }.join("\n")
    decision = fields["sequence_decision"] || "not applicable"
    position_after = if %w[partial aborted].include?(fields["status"]) && fields["sequence_decision"] == "repeat"
      fields["sequence_position_before"]
    else
      fields["template"]
    end
    body = <<~MARKDOWN
      # Session Log

      ## Lifecycle and Sequence

      - Plan status at time of session: active
      - Session status: #{fields["status"]}
      - Sequence decision: #{decision}
      - Sequence position after this outcome: #{position_after || "none"}
      - Next session template: #{fields["next_session"]}

      ## Prescribed Work

      | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
      | --- | --- | --- | --- | --- |
      | Goblet squat | 3 | 8-10 | 7 | Controlled tempo |

      ## Actual Work

      | Exercise | Actual sets | Actual reps | Load | Actual RPE | Notes |
      | --- | --- | --- | --- | --- | --- |
      | Goblet squat | 3 | 10, 9, 9 | 18 kg | 7, 7, 8 | Tempo stayed controlled |

      ## Optional Cardio

      - Performed?: no
      - Modality: none
      - Minutes: 0
      - Intensity: none
      - Notes: none

      ## Integrated Conditioning

      - Performed?: no
      - Modality: none
      - Prescribed minutes and intensity: none
      - Actual minutes and intensity: none
      - Credited minutes: 0
      - Total duration impact: none
      - Strength-volume impact: none
      - Lower-body impact: none
      - Rationale: none planned

      ## Duration and Notes

      - Planned total duration: 60 minutes
      - Actual total duration: 58 minutes
      - Pain, fatigue, or recovery notes: no pain
      - Other notes: completed as recorded
    MARKDOWN
    write(root, "blocks/#{block}/sessions/#{filename}", "---\n#{front_matter}\n---\n\n#{body}")
  end

  def write_active_state(root, plan_status: "active", position: nil, next_session: "A", block_number: 1)
    write(root, "_system/state/current.yaml", <<~YAML)
      active_block: 2026-09-block-001
      plan_status: #{plan_status}
      default_sequence: [A, B, C]
      sequence_position: #{yaml_value(position)}
      next_session: #{next_session}
      block_number: #{block_number}
    YAML
  end

  def write_review(root, block: "2026-09-block-001", metadata: {}, headings: REQUIRED_REVIEW_HEADINGS)
    fields = {
      "block_number" => 1, "review_date" => Date.new(2026, 9, 30), "plan_status" => "completed"
    }.merge(metadata)
    front_matter = fields.map { |key, value| "#{key}: #{yaml_value(value)}" }.join("\n")
    body = headings.map { |heading| "## #{heading}\n\nPopulated review notes." }.join("\n\n")
    write(root, "blocks/#{block}/review.md", "---\n#{front_matter}\n---\n\n# Block Review\n\n#{body}\n")
  end

  def write(root, relative_path, contents)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
  end

  def rewrite(root, relative_path)
    path = File.join(root, relative_path)
    File.write(path, yield(File.read(path)))
  end

  def yaml_value(value)
    case value
    when Array then "[#{value.map(&:inspect).join(', ')}]"
    when Date then value.iso8601
    when String then value.inspect
    when NilClass then "null"
    else value.to_s
    end
  end

  def diagnostics(root)
    assert_nil REPOSITORY_VALIDATOR_LOAD_ERROR, "validator must be loadable: #{REPOSITORY_VALIDATOR_LOAD_ERROR}"

    TrainingSystem::RepositoryValidator.new(root).call
  end

  def codes(root)
    diagnostics(root).map(&:code)
  end

  def test_validator_loads
    assert_nil REPOSITORY_VALIDATOR_LOAD_ERROR, "validator must be loadable: #{REPOSITORY_VALIDATOR_LOAD_ERROR}"
  end

  def test_reports_missing_core_file_with_path
    with_repository do |root|
      File.delete(File.join(root, "data/profile.yaml"))

      diagnostic = diagnostics(root).find { |item| item.code == "missing_core_file" }
      assert_equal "error", diagnostic.severity
      assert_equal "data/profile.yaml", diagnostic.path
    end
  end

  def test_turns_invalid_top_level_yaml_type_into_path_aware_diagnostic
    with_repository do |root|
      write(root, "data/profile.yaml", "not-a-mapping\n")

      diagnostic = diagnostics(root).find { |item| item.code == "invalid_yaml_type" }
      assert_equal "data/profile.yaml", diagnostic.path
      assert_equal "error", diagnostic.severity
    end
  end

  def test_turns_wrong_health_field_type_into_a_diagnostic_without_crashing
    with_repository do |root|
      write(root, "data/profile.yaml", "health: needs_review\n")

      diagnostic = diagnostics(root).find { |item| item.code == "invalid_field_type" }
      assert_equal "data/profile.yaml.health", diagnostic.path
    end
  end

  def test_rejects_empty_profile_and_equipment_mappings_instead_of_clearing_readiness
    with_repository do |root|
      write(root, "data/profile.yaml", "{}\n")
      write(root, "data/equipment.yaml", "{}\n")

      error_paths = diagnostics(root).select { |item| item.severity == "error" }.map(&:path)
      assert_includes error_paths, "data/profile.yaml.health"
      assert_includes error_paths, "data/equipment.yaml.review_status"
    end
  end

  def test_requires_health_mapping_and_its_review_status
    with_repository do |root|
      write(root, "data/profile.yaml", "version: 1\n")

      diagnostic = diagnostics(root).find { |item| item.path == "data/profile.yaml.health" }
      refute_nil diagnostic
      assert_equal "missing_required_field", diagnostic.code

      write(root, "data/profile.yaml", "health: {}\n")

      diagnostic = diagnostics(root).find { |item| item.path == "data/profile.yaml.health.review_status" }
      refute_nil diagnostic
      assert_equal "missing_required_field", diagnostic.code
    end
  end

  def test_requires_equipment_review_status
    with_repository do |root|
      write(root, "data/equipment.yaml", "version: 1\nitems: []\n")

      diagnostic = diagnostics(root).find { |item| item.path == "data/equipment.yaml.review_status" }
      refute_nil diagnostic
      assert_equal "missing_required_field", diagnostic.code
    end
  end

  def test_rejects_non_scalar_health_and_equipment_review_statuses
    with_repository do |root|
      write(root, "data/profile.yaml", "health: { review_status: [needs_review] }\n")
      write(root, "data/equipment.yaml", "review_status: [needs_input]\n")

      assert_includes codes(root), "invalid_health_review_status"
      assert_includes codes(root), "invalid_equipment_review_status"
    end
  end

  def test_rejects_null_health_mapping_and_null_review_statuses
    with_repository do |root|
      write(root, "data/profile.yaml", "health: null\n")
      write(root, "data/equipment.yaml", "review_status: null\n")

      error_paths = diagnostics(root).select { |item| item.severity == "error" }.map(&:path)
      assert_includes error_paths, "data/profile.yaml.health"
      assert_includes error_paths, "data/equipment.yaml.review_status"
    end
  end

  def test_rejects_unknown_health_and_equipment_review_statuses
    with_repository do |root|
      write(root, "data/profile.yaml", "health: { review_status: pending }\n")
      write(root, "data/equipment.yaml", "review_status: pending\n")

      assert_includes codes(root), "invalid_health_review_status"
      assert_includes codes(root), "invalid_equipment_review_status"
    end
  end

  def test_turns_invalid_yaml_in_exercise_library_and_calendar_into_diagnostics
    with_repository do |root|
      write(root, "data/exercise_library.yaml", "items: [\n")
      write(root, "calendar/exceptions.yaml", "exceptions: [\n")

      diagnostics_by_path = diagnostics(root).select { |item| item.code == "invalid_yaml" }.map(&:path)
      assert_includes diagnostics_by_path, "data/exercise_library.yaml"
      assert_includes diagnostics_by_path, "calendar/exceptions.yaml"
    end
  end

  def test_turns_wrong_yaml_roots_in_exercise_library_and_calendar_into_diagnostics
    with_repository do |root|
      write(root, "data/exercise_library.yaml", "- squat\n")
      write(root, "calendar/exceptions.yaml", "- travel\n")

      diagnostics_by_path = diagnostics(root).select { |item| item.code == "invalid_yaml_type" }.map(&:path)
      assert_includes diagnostics_by_path, "data/exercise_library.yaml"
      assert_includes diagnostics_by_path, "calendar/exceptions.yaml"
    end
  end

  def test_rejects_invalid_default_sequence_without_crashing
    with_repository do |root|
      write(root, "_system/state/current.yaml", "default_sequence: [A, A]\nsequence_position: A\nnext_session: A\n")

      diagnostic = diagnostics(root).find { |item| item.code == "invalid_default_sequence" }
      assert_equal "_system/state/current.yaml.default_sequence", diagnostic.path
    end
  end

  def test_emits_exact_onboarding_warnings_for_canonical_repository
    with_repository do |root|
      warnings = diagnostics(root).select { |item| item.severity == "warning" }.map(&:code)

      assert_equal %w[equipment_needs_input health_needs_review], warnings.sort
      assert_empty diagnostics(root).select { |item| item.severity == "error" }
    end
  end

  def test_rejects_active_block_with_draft_plan
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "draft" })
      write_active_state(root)

      assert_includes codes(root), "active_plan_is_draft"
    end
  end

  def test_active_block_requires_active_status_in_both_plan_and_state
    %w[approved draft completed].each do |plan_status|
      with_repository do |root|
        write_active_plan(root, metadata: { "status" => plan_status })
        write_active_state(root)

        diagnostic = diagnostics(root).find { |item| item.code == "active_plan_status_mismatch" }
        refute_nil diagnostic, "#{plan_status} plan must not remain active"
        assert_equal "blocks/2026-09-block-001/plan.md.status", diagnostic.path
      end
    end

    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "active" })
      write_active_state(root, plan_status: "approved")

      diagnostic = diagnostics(root).find { |item| item.code == "active_state_plan_status_mismatch" }
      refute_nil diagnostic
      assert_equal "_system/state/current.yaml.plan_status", diagnostic.path
    end
  end

  def test_active_plan_sequence_governs_wrap_instead_of_default_sequence
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "active", "sequence" => %w[A B] })
      write_session_log(root)
      write_session_log(root, filename: "02-B.md", metadata: {
        "date" => "2026-09-03", "session_number" => 2, "template" => "B",
        "sequence_position_before" => "A", "next_session" => "A"
      })
      write_active_state(root, position: "B", next_session: "A")

      refute_includes codes(root), "mismatched_next_session"
    end
  end

  def test_active_state_still_requires_structurally_valid_default_sequence
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "active", "sequence" => %w[A B] })
      write_active_state(root)
      rewrite(root, "_system/state/current.yaml") do |document|
        document.sub("default_sequence: [A, B, C]", "default_sequence: [A, A]")
      end

      assert_includes codes(root), "invalid_default_sequence"
    end
  end

  def test_plan_block_number_must_be_positive_and_match_its_directory_suffix
    with_repository do |root|
      write_active_plan(root, metadata: { "block_number" => 0 })

      diagnostic = diagnostics(root).find { |item| item.code == "invalid_plan_block_number" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/plan.md.block_number", diagnostic.path
    end

    with_repository do |root|
      write_active_plan(root, metadata: { "block_number" => 2 })

      diagnostic = diagnostics(root).find { |item| item.code == "mismatched_plan_block_number" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/plan.md.block_number", diagnostic.path
    end
  end

  def test_active_plan_block_number_must_match_state
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "active" })
      write_active_state(root, block_number: 2)

      diagnostic = diagnostics(root).find { |item| item.code == "mismatched_active_block_number" }
      refute_nil diagnostic
      assert_equal "_system/state/current.yaml.block_number", diagnostic.path
    end
  end

  def test_rejects_block_duration_outside_contract
    with_repository do |root|
      write_active_plan(root, metadata: { "planned_duration_weeks" => 2, "target_strength_sessions" => 6 })

      assert_includes codes(root), "invalid_block_duration"
    end
  end

  def test_rejects_current_next_session_that_does_not_follow_position
    with_repository do |root|
      write(root, "_system/state/current.yaml", "default_sequence: [A, B, C]\nsequence_position: A\nnext_session: C\n")

      diagnostic = diagnostics(root).find { |item| item.code == "mismatched_next_session" }
      assert_equal "_system/state/current.yaml.next_session", diagnostic.path
    end
  end

  def test_rejects_plan_missing_required_headings
    with_repository do |root|
      write_active_plan(root, headings: ["Block Intent"])

      assert_includes codes(root), "missing_plan_heading"
    end
  end

  def test_requires_a_template_subsection_for_each_declared_sequence_template
    with_repository do |root|
      write_active_plan(root, headings: REQUIRED_HEADINGS + ["Template A", "Template B"], include_template_headings: false)

      diagnostic = diagnostics(root).find { |item| item.code == "missing_template_section" }
      assert_equal "blocks/2026-09-block-001/plan.md", diagnostic.path
      assert_includes diagnostic.message, "Template C"
    end
  end

  def test_rejects_session_with_unknown_template
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, metadata: { "template" => "D" })

      assert_includes codes(root), "unknown_session_template"
    end
  end

  def test_rejects_session_filename_and_metadata_mismatch
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, filename: "01-A.md", metadata: { "session_number" => 2, "template" => "B" })

      assert_includes codes(root), "session_filename_mismatch"
    end
  end

  def test_rejects_invalid_session_status
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, metadata: { "status" => "scheduled" })

      assert_includes codes(root), "invalid_session_status"
    end
  end

  def test_requires_decision_for_partial_or_aborted_session
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, metadata: { "status" => "partial", "sequence_decision" => nil })

      assert_includes codes(root), "missing_sequence_decision"
    end
  end

  def test_rejects_session_with_impossible_sequence_position_before
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, metadata: { "sequence_position_before" => "Z" })

      diagnostic = diagnostics(root).find { |item| item.code == "invalid_sequence_position_before" }
      assert_equal "blocks/2026-09-block-001/sessions/01-A.md.sequence_position_before", diagnostic.path
    end
  end

  def test_rejects_session_template_that_does_not_follow_its_prior_position
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, filename: "01-C.md", metadata: { "template" => "C", "sequence_position_before" => "A", "next_session" => "A" })

      assert_includes codes(root), "mismatched_session_template"
    end
  end

  def test_rejects_noncanonical_block_directory_and_invalid_month
    with_repository do |root|
      write_active_plan(root, name: "2026-13-block-001")

      diagnostic = diagnostics(root).find { |item| item.code == "invalid_block_directory_name" }
      refute_nil diagnostic
      assert_equal "blocks/2026-13-block-001", diagnostic.path
    end

    with_repository do |root|
      write_active_plan(root, name: "block-001")

      assert_includes codes(root), "invalid_block_directory_name"
    end
  end

  def test_rejects_session_filename_without_exact_two_digit_number
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, filename: "1-A.md")

      diagnostic = diagnostics(root).find { |item| item.code == "invalid_session_filename" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/sessions/1-A.md", diagnostic.path
    end
  end

  def test_rejects_gapped_and_duplicate_session_numbers
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root)
      write_session_log(root, filename: "03-B.md", metadata: {
        "date" => "2026-09-03", "session_number" => 3, "template" => "B",
        "sequence_position_before" => "A", "next_session" => "C"
      })

      diagnostic = diagnostics(root).find { |item| item.code == "noncontiguous_session_numbers" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/sessions", diagnostic.path
    end

    with_repository do |root|
      write_active_plan(root)
      write_session_log(root)
      write_session_log(root, filename: "01-B.md", metadata: {
        "template" => "B", "sequence_position_before" => "A", "next_session" => "C"
      })

      assert_includes codes(root), "duplicate_session_number"
    end
  end

  def test_replay_requires_nil_first_position_and_previous_outcome_position_afterward
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, metadata: { "sequence_position_before" => "C" })

      diagnostic = diagnostics(root).find { |item| item.code == "broken_session_chain" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/sessions/01-A.md.sequence_position_before", diagnostic.path
    end

    with_repository do |root|
      write_active_plan(root)
      write_session_log(root)
      write_session_log(root, filename: "02-B.md", metadata: {
        "date" => "2026-09-03", "session_number" => 2, "template" => "B",
        "sequence_position_before" => "C", "next_session" => "C"
      })

      diagnostic = diagnostics(root).find { |item| item.code == "broken_session_chain" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/sessions/02-B.md.sequence_position_before", diagnostic.path
    end
  end

  def test_replay_advances_or_repeats_position_from_outcome
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "active" })
      write_session_log(root, metadata: {
        "status" => "partial", "sequence_decision" => "repeat", "next_session" => "A",
        "credited_strength_session" => false
      })
      write_session_log(root, filename: "02-A.md", metadata: {
        "date" => "2026-09-03", "session_number" => 2, "status" => "aborted",
        "sequence_decision" => "advance", "next_session" => "B", "credited_strength_session" => false
      })
      write_active_state(root, position: "A", next_session: "B")

      replay_errors = codes(root) & %w[broken_session_chain mismatched_next_session mismatched_active_sequence_position]
      assert_empty replay_errors
    end
  end

  def test_rejects_active_state_stale_against_replayed_sessions
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "active" })
      write_session_log(root)
      write_active_state(root, position: nil, next_session: "A")

      assert_includes codes(root), "mismatched_active_sequence_position"
      assert_includes codes(root), "mismatched_next_session"
    end
  end

  def test_active_state_without_sessions_starts_at_first_plan_template
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "active" })
      write_active_state(root, position: "A", next_session: "B")

      assert_includes codes(root), "mismatched_active_sequence_position"
      assert_includes codes(root), "mismatched_next_session"
    end
  end

  def test_session_block_number_must_match_plan
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root, metadata: { "block_number" => 2 })

      diagnostic = diagnostics(root).find { |item| item.code == "mismatched_session_block_number" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/sessions/01-A.md.block_number", diagnostic.path
    end
  end

  def test_completed_plan_requires_review
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "completed" })

      diagnostic = diagnostics(root).find { |item| item.code == "missing_block_review" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/review.md", diagnostic.path
    end
  end

  def test_completed_review_requires_matching_metadata
    {
      { "block_number" => 0 } => ["invalid_review_block_number", "blocks/2026-09-block-001/review.md.block_number"],
      { "block_number" => 2 } => ["mismatched_review_block_number", "blocks/2026-09-block-001/review.md.block_number"],
      { "plan_status" => "active" } => ["invalid_review_plan_status", "blocks/2026-09-block-001/review.md.plan_status"],
      { "review_date" => "eventually" } => ["invalid_review_date", "blocks/2026-09-block-001/review.md.review_date"]
    }.each do |metadata, (code, path)|
      with_repository do |root|
        write_active_plan(root, metadata: { "status" => "completed" })
        write_review(root, metadata: metadata)

        diagnostic = diagnostics(root).find { |item| item.code == code }
        refute_nil diagnostic, "expected #{code} for #{metadata.inspect}"
        assert_equal path, diagnostic.path
      end
    end
  end

  def test_completed_review_requires_every_template_heading_as_h2
    with_repository do |root|
      write_active_plan(root, metadata: { "status" => "completed" })
      write_review(root, headings: REQUIRED_REVIEW_HEADINGS - ["Cardio"])

      diagnostic = diagnostics(root).find { |item| item.code == "missing_review_heading" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/review.md", diagnostic.path
      assert_includes diagnostic.message, "Cardio"
    end
  end

  def test_requires_positive_integer_weekly_strength_frequency
    [nil, "3", 0, -1].each do |frequency|
      with_repository do |root|
        write_active_plan(root, metadata: { "weekly_strength_frequency" => frequency })

        diagnostic = diagnostics(root).find { |item| item.code == "invalid_weekly_strength_frequency" }
        refute_nil diagnostic, "expected invalid frequency for #{frequency.inspect}"
        assert_equal "blocks/2026-09-block-001/plan.md.weekly_strength_frequency", diagnostic.path
      end
    end

    with_repository do |root|
      write_active_plan(root)
      rewrite(root, "blocks/2026-09-block-001/plan.md") do |document|
        document.lines.reject { |line| line.start_with?("weekly_strength_frequency:") }.join
      end

      assert_includes codes(root), "invalid_weekly_strength_frequency"
    end
  end

  def test_target_strength_sessions_must_be_exact_integer_product
    with_repository do |root|
      write_active_plan(root, metadata: { "target_strength_sessions" => "12" })

      assert_includes codes(root), "invalid_target_strength_sessions"
    end

    with_repository do |root|
      write_active_plan(root, metadata: { "target_strength_sessions" => 11 })

      assert_includes codes(root), "mismatched_target_strength_sessions"
    end
  end

  def test_each_plan_template_requires_nonempty_exact_planned_work_table
    with_repository do |root|
      write_active_plan(root)
      rewrite(root, "blocks/2026-09-block-001/plan.md") do |document|
        document.sub("| Goblet squat | 3 | 8-10 | 7 | Controlled tempo |\n", "")
      end

      assert_includes codes(root), "empty_planned_work_table"
    end

    with_repository do |root|
      write_active_plan(root)
      rewrite(root, "blocks/2026-09-block-001/plan.md") do |document|
        document.sub("| Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |",
                     "| Exercise | Sets | Prescribed reps | Target RPE | Notes |")
      end

      assert_includes codes(root), "invalid_planned_work_schema"
    end
  end

  def test_rejects_planned_load_columns_and_numeric_planned_loads
    with_repository do |root|
      write_active_plan(root)
      rewrite(root, "blocks/2026-09-block-001/plan.md") do |document|
        document.sub("| Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |",
                     "| Exercise | Prescribed sets | Prescribed reps | Target RPE | Weight |")
      end

      assert_includes codes(root), "planned_load_column"
    end

    with_repository do |root|
      write_active_plan(root)
      rewrite(root, "blocks/2026-09-block-001/plan.md") do |document|
        document.sub("Controlled tempo", "Use 12 kg")
      end

      assert_includes codes(root), "numeric_planned_load"
    end
  end

  def test_plan_integrated_conditioning_requires_each_explicit_field
    with_repository do |root|
      write_active_plan(root)
      rewrite(root, "blocks/2026-09-block-001/plan.md") do |document|
        document.sub("- Rationale: none planned", "- Rationale:")
      end

      diagnostic = diagnostics(root).find { |item| item.code == "missing_integrated_conditioning_field" }
      refute_nil diagnostic
      assert_equal "blocks/2026-09-block-001/plan.md", diagnostic.path
      assert_includes diagnostic.message, "Rationale"
    end
  end

  def test_rejects_metadata_only_session_log
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root)
      rewrite(root, "blocks/2026-09-block-001/sessions/01-A.md") do |document|
        document.sub(/# Session Log.*\z/m, "# Session Log\n")
      end

      assert_includes codes(root), "missing_session_heading"
    end
  end

  def test_session_work_tables_must_be_nonempty_and_use_exact_schemas
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root)
      rewrite(root, "blocks/2026-09-block-001/sessions/01-A.md") do |document|
        document.sub("| Goblet squat | 3 | 8-10 | 7 | Controlled tempo |\n", "")
      end

      assert_includes codes(root), "empty_session_work_table"
    end

    with_repository do |root|
      write_active_plan(root)
      write_session_log(root)
      rewrite(root, "blocks/2026-09-block-001/sessions/01-A.md") do |document|
        document.sub("| Exercise | Actual sets | Actual reps | Load | Actual RPE | Notes |",
                     "| Exercise | Actual sets | Actual reps | Resistance | Actual RPE | Notes |")
      end

      assert_includes codes(root), "invalid_actual_work_schema"
    end
  end

  def test_session_requires_nonblank_lifecycle_cardio_conditioning_and_duration_fields
    {
      "- Session status: completed" => "- Session status:",
      "- Sequence decision: not applicable" => "- Sequence decision:",
      "- Minutes: 0" => "- Minutes:",
      "- Pain, fatigue, or recovery notes: no pain" => "- Pain, fatigue, or recovery notes:",
      "- Rationale: none planned" => "- Rationale:"
    }.each do |present, blank|
      with_repository do |root|
        write_active_plan(root)
        write_session_log(root)
        rewrite(root, "blocks/2026-09-block-001/sessions/01-A.md") do |document|
          document.sub(present, blank)
        end

        diagnostic = diagnostics(root).find { |item| item.code == "missing_session_field" }
        refute_nil diagnostic, "expected a missing field diagnostic after replacing #{present.inspect}"
      end
    end
  end

  def test_actual_logged_loads_remain_valid
    with_repository do |root|
      write_active_plan(root)
      write_session_log(root)

      errors = diagnostics(root).select { |item| item.severity == "error" }
      assert_empty errors
      assert_includes File.read(File.join(root, "blocks/2026-09-block-001/sessions/01-A.md")), "18 kg"
    end
  end

  def test_cli_asserts_script_exists_before_running_warning_and_error_cases
    script = File.join(ROOT, "bin/validate")
    assert File.exist?(script), "bin/validate must exist before CLI execution"

    with_repository do |root|
      _output, status = Open3.capture2e(script, root)
      assert_predicate status, :success?

      File.delete(File.join(root, "data/profile.yaml"))
      _output, status = Open3.capture2e(script, root)
      refute_predicate status, :success?
      assert_equal 1, status.exitstatus
    end
  end
end
