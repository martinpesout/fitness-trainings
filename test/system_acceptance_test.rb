# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "yaml"

class SystemAcceptanceTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  VALIDATOR = File.join(ROOT, "bin/validate")
  BLOCK = "2026-09-block-001"
  NOVEL_EXERCISE = "Half-kneeling single-arm landmine press"
  SESSION_DATES = {
    1 => "2026-09-01", 2 => "2026-09-06", 3 => "2026-09-08", 4 => "2026-09-10"
  }.freeze
  PLANNED_EXERCISE_SCHEMA = ["Exercise", "Prescribed sets", "Prescribed reps", "Target RPE", "Notes"].freeze
  ACTUAL_EXERCISE_SCHEMA = ["Exercise", "Actual sets", "Actual reps", "Load", "Actual RPE", "Notes"].freeze
  DIAGNOSTIC_CODE = /\A(?:ERROR|WARNING) (?<code>\S+)/

  ValidationRun = Struct.new(:output, :status, keyword_init: true) do
    def codes
      output.lines.filter_map { |line| DIAGNOSTIC_CODE.match(line)&.[](:code) }
    end
  end

  def test_complete_first_block_workflow_through_the_validator_cli
    with_repository do |root|
      assert_validation(root, %w[equipment_needs_input health_needs_review], "onboarding")
      assert_state(root, position: nil, next_session: "A", label: "onboarding")

      confirm_health_and_equipment(root)
      assert_validation(root, [], "confirmed onboarding")

      plan_path = write_approved_plan(root)
      activate_plan(root, position: nil, next_session: "A")
      assert_validation(root, [], "active five-week plan")
      assert_plan_contract(root, plan_path)
      assert_state(root, position: nil, next_session: "A", label: "active plan")

      write_session(root, number: 1, template: "A", status: "completed",
                    position_before: nil, next_session: "B")
      activate_plan(root, position: "A", next_session: "B")
      assert_validation(root, [], "completed A")
      assert_state(root, position: "A", next_session: "B", label: "completed A")

      record_cancelled_date(root)
      assert_equal ["01-A.md"], session_filenames(root), "a cancelled date must not create a session outcome"
      assert_validation(root, [], "cancelled date")
      assert_state(root, position: "A", next_session: "B", label: "cancelled date")

      write_session(root, number: 2, template: "B", status: "partial",
                    position_before: "A", decision: "repeat", next_session: "B")
      activate_plan(root, position: "A", next_session: "B")
      assert_validation(root, [], "partial B with repeat")
      assert_state(root, position: "A", next_session: "B", label: "partial B with repeat")

      write_session(root, number: 3, template: "B", status: "completed",
                    position_before: "A", next_session: "C")
      activate_plan(root, position: "B", next_session: "C")
      assert_validation(root, [], "repeated B completed")
      assert_state(root, position: "B", next_session: "C", label: "repeated B completed")

      write_session(root, number: 4, template: "C", status: "completed",
                    position_before: "B", next_session: "A", integrated_cycling: true)
      activate_plan(root, position: "C", next_session: "A")
      assert_validation(root, [], "integrated cycling after C")
      assert_state(root, position: "C", next_session: "A", label: "integrated cycling after C")
      assert_filled_session_logs(root)
      assert_integrated_cycling(root)

      write_completed_review(root)
      set_plan_status(root, "completed")
      close_block(root, position: "C", next_session: "A")
      assert_validation(root, [], "completed block closure")
      assert_state(root, position: "C", next_session: "A", label: "completed block closure")
      assert_completed_lifecycle(root)
    end
  end

  private

  def with_repository
    Dir.mktmpdir("training-system-acceptance") do |root|
      %w[data calendar _system].each do |entry|
        FileUtils.cp_r(File.join(ROOT, entry), root)
      end
      FileUtils.mkdir_p(File.join(root, "blocks"))
      seed_onboarding_state(root)
      yield root
    end
  end

  def seed_onboarding_state(root)
    profile = read_yaml(root, "data/profile.yaml")
    profile.fetch("health")["review_status"] = "needs_review"
    write_yaml(root, "data/profile.yaml", profile)

    equipment = read_yaml(root, "data/equipment.yaml")
    equipment["review_status"] = "needs_input"
    equipment["items"] = []
    write_yaml(root, "data/equipment.yaml", equipment)

    write_yaml(root, "data/exercise_library.yaml", {
      "version" => 1,
      "exercises" => [{ "name" => "Goblet squat" }]
    })
    write_yaml(root, "_system/state/current.yaml", {
      "version" => 1,
      "active_block" => nil,
      "plan_status" => nil,
      "default_sequence" => %w[A B C],
      "sequence_position" => nil,
      "next_session" => "A",
      "block_number" => 0
    })
  end

  def confirm_health_and_equipment(root)
    profile = read_yaml(root, "data/profile.yaml")
    profile.fetch("health")["review_status"] = "confirmed"
    write_yaml(root, "data/profile.yaml", profile)

    equipment = read_yaml(root, "data/equipment.yaml")
    equipment["review_status"] = "confirmed"
    equipment["items"] = ["adjustable dumbbells", "bench", "stationary bicycle"]
    write_yaml(root, "data/equipment.yaml", equipment)
  end

  def write_approved_plan(root)
    path = File.join(root, "blocks", BLOCK, "plan.md")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, <<~MARKDOWN)
      ---
      status: approved
      block_number: 1
      planned_duration_weeks: 5
      weekly_strength_frequency: 3
      target_strength_sessions: 15
      sequence: [A, B, C]
      approved_changes: []
      ---

      # Five-week strength and cycling block

      ## Block Intent

      Build repeatable full-body strength while keeping one moderate cycling segment.

      ## Lifecycle

      This plan is approved and may be active.

      ## Duration and Session Target

      Five weeks at three strength sessions per week gives 15 target strength sessions.

      ## Shared Rules

      Select each working weight from the target RPE. Record the actual weight only in the session log.

      ## Session Templates

      ### Template A

      | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
      | --- | --- | --- | --- | --- |
      | Goblet squat | 3 | 8-10 | 7 | Controlled tempo |
      | #{NOVEL_EXERCISE} | 3 | 8-10 per side | 7 | [Technique search](https://www.youtube.com/results?search_query=half-kneeling+single-arm+landmine+press) |

      ### Template B

      | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
      | --- | --- | --- | --- | --- |
      | Dumbbell Romanian deadlift | 3 | 8-10 | 7 | Stop with stable trunk position |
      | One-arm dumbbell row | 3 | 8-12 per side | 8 | Full controlled range |

      ### Template C

      | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
      | --- | --- | --- | --- | --- |
      | Reverse lunge | 2 | 8-10 per side | 7 | Lower-body volume reduced for cycling |
      | Dumbbell floor press | 3 | 8-12 | 8 | Pause on each repetition |

      ## Progression

      Add repetitions within the range before choosing a higher load at the same target RPE.

      ## Optional Cardio

      An easy walk may be skipped and does not count toward strength adherence.

      ## Integrated Conditioning

      - Session template: C
      - Modality: stationary cycling
      - Minutes and intensity: 12 minutes at RPE 6
      - Total-duration impact: adds 12 minutes to Template C
      - Strength-volume impact: removes one accessory working set
      - Lower-body impact: reduces lunges from 4 to 2 working sets
      - Rationale: moderate cycling replaces lower-body volume instead of stacking fatigue

      ## Approved Changes

      None.
    MARKDOWN
    path
  end

  def activate_plan(root, position:, next_session:)
    set_plan_status(root, "active")
    write_yaml(root, "_system/state/current.yaml", {
      "version" => 1,
      "active_block" => BLOCK,
      "plan_status" => "active",
      "default_sequence" => %w[A B C],
      "sequence_position" => position,
      "next_session" => next_session,
      "block_number" => 1
    })
  end

  def set_plan_status(root, status)
    path = File.join(root, "blocks", BLOCK, "plan.md")
    document = File.read(path)
    raise "plan status was not found" unless document.match?(/^status:\s+\w+$/)

    File.write(path, document.sub(/^status:\s+\w+$/, "status: #{status}"))
  end

  def close_block(root, position:, next_session:)
    write_yaml(root, "_system/state/current.yaml", {
      "version" => 1,
      "active_block" => nil,
      "plan_status" => nil,
      "default_sequence" => %w[A B C],
      "sequence_position" => position,
      "next_session" => next_session,
      "block_number" => 1
    })
  end

  def write_completed_review(root)
    path = File.join(root, "blocks", BLOCK, "review.md")
    File.write(path, <<~MARKDOWN)
      ---
      block_number: 1
      review_date: 2026-09-12
      plan_status: completed
      ---

      # Block Review

      ## Adherence

      - Target strength sessions: 15
      - Completed strength sessions: 3
      - Partial or aborted sessions: 1
      - Completion rate: 20 percent completed, with one additional partial session
      - Why sessions were missed, shortened, or moved: one B session ended early because grip fatigue rose

      ## RPE and Progress

      - RPE trend: target RPE stayed controlled across completed sessions
      - Progress on primary movements: the repeated B session restored full prescribed volume
      - Exercises that stalled or regressed: none identified in this short acceptance fixture

      ## Novelty

      - New movements or patterns tried: #{NOVEL_EXERCISE}
      - What to retain, change, or remove: retain the press with the slower setup cue

      ## Fatigue and Pain

      - Fatigue trend and recovery: grip recovered before the repeated B session
      - Pain, symptoms, or constraints: no pain was recorded
      - Any health follow-up needed: none from this block

      ## Cardio

      - Optional cardio completed, minutes, and response: none
      - Integrated conditioning completed, minutes, and response: 12 minutes of cycling at RPE 6
      - Effect on strength volume and lower-body recovery: lunges stayed at two working sets and recovery remained normal

      ## Next-Block Recommendation

      - Recommended duration, frequency, and sequence: four weeks, three sessions weekly, A/B/C
      - Recommended progression, deload, or adjustment: progress repetitions before load and keep reduced lunge volume with cycling
      - Recommendation rationale: recorded RPE and recovery stayed controlled
    MARKDOWN
  end

  def assert_completed_lifecycle(root)
    state = read_yaml(root, "_system/state/current.yaml")
    assert_nil state["active_block"]
    assert_nil state["plan_status"]
    assert_equal 1, state["block_number"]

    plan = document_metadata(File.read(File.join(root, "blocks", BLOCK, "plan.md")))
    review = document_metadata(File.read(File.join(root, "blocks", BLOCK, "review.md")))
    assert_equal "completed", plan.fetch("status")
    assert_equal "completed", review.fetch("plan_status")
    assert_equal 1, review.fetch("block_number")
    assert_instance_of Date, review.fetch("review_date")
  end

  def record_cancelled_date(root)
    write_yaml(root, "calendar/exceptions.yaml", {
      "version" => 1,
      "exceptions" => [{
        "date" => "2026-09-04",
        "type" => "cancelled",
        "reason" => "schedule conflict"
      }]
    })
  end

  def write_session(root, number:, template:, status:, position_before:, next_session:, decision: nil,
                    integrated_cycling: false)
    filename = format("%02d-%s.md", number, template)
    path = File.join(root, "blocks", BLOCK, "sessions", filename)
    FileUtils.mkdir_p(File.dirname(path))
    metadata = {
      "date" => SESSION_DATES.fetch(number),
      "block_number" => 1,
      "session_number" => number,
      "template" => template,
      "status" => status,
      "sequence_position_before" => position_before,
      "sequence_decision" => decision,
      "next_session" => next_session,
      "credited_strength_session" => status == "completed"
    }
    position_after = status == "completed" ? template : position_before
    body = <<~MARKDOWN
      # Session Log

      ## Lifecycle and Sequence

      - Plan status at time of session: active
      - Session status: #{status}
      - Sequence decision: #{decision || "not applicable"}
      - Sequence position after this outcome: #{position_after}
      - Next session template: #{next_session}

      #{session_work(number)}

      ## Optional Cardio

      - Performed?: no
      - Modality: none
      - Minutes: 0
      - Intensity: none
      - Notes: skipped without changing strength adherence

      #{integrated_conditioning(integrated_cycling)}

      #{duration_and_notes(number)}
    MARKDOWN
    File.write(path, YAML.dump(metadata) + "---\n\n#{body}")
  end

  def session_work(number)
    case number
    when 1
      <<~MARKDOWN
        ## Prescribed Work

        | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
        | --- | --- | --- | --- | --- |
        | Goblet squat | 3 | 8-10 | 7 | Controlled tempo |
        | #{NOVEL_EXERCISE} | 3 | 8-10 per side | 7 | Stable half-kneeling position |

        ## Actual Work

        | Exercise | Actual sets | Actual reps | Load | Actual RPE | Notes |
        | --- | --- | --- | --- | --- | --- |
        | Goblet squat | 3 | 10, 9, 9 | 18 kg | 7, 7, 8 | Tempo stayed controlled |
        | #{NOVEL_EXERCISE} | 3 | 10, 9, 8 per side | 10 kg | 7, 8, 8 | Left side needed a slower setup |
      MARKDOWN
    when 2
      <<~MARKDOWN
        ## Prescribed Work

        | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
        | --- | --- | --- | --- | --- |
        | Dumbbell Romanian deadlift | 3 | 8-10 | 7 | Stop with stable trunk position |
        | One-arm dumbbell row | 3 | 8-12 per side | 8 | Full controlled range |

        ## Actual Work

        | Exercise | Actual sets | Actual reps | Load | Actual RPE | Notes |
        | --- | --- | --- | --- | --- | --- |
        | Dumbbell Romanian deadlift | 2 | 9, 8 | 20 kg | 7, 8 | Grip fatigue rose during set two |
        | One-arm dumbbell row | 2 | 10, 9 per side | 12 kg | 8, 8 | Stopped before form changed |
      MARKDOWN
    when 3
      <<~MARKDOWN
        ## Prescribed Work

        | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
        | --- | --- | --- | --- | --- |
        | Dumbbell Romanian deadlift | 3 | 8-10 | 7 | Stop with stable trunk position |
        | One-arm dumbbell row | 3 | 8-12 per side | 8 | Full controlled range |

        ## Actual Work

        | Exercise | Actual sets | Actual reps | Load | Actual RPE | Notes |
        | --- | --- | --- | --- | --- | --- |
        | Dumbbell Romanian deadlift | 3 | 10, 9, 9 | 20 kg | 7, 7, 8 | Grip stayed reliable |
        | One-arm dumbbell row | 3 | 11, 10, 10 per side | 12 kg | 7, 8, 8 | Full range on every repetition |
      MARKDOWN
    when 4
      <<~MARKDOWN
        ## Prescribed Work

        | Exercise | Prescribed sets | Prescribed reps | Target RPE | Notes |
        | --- | --- | --- | --- | --- |
        | Reverse lunge | 2 | 8-10 per side | 7 | Reduced from four sets for cycling |
        | Dumbbell floor press | 3 | 8-12 | 8 | Pause on each repetition |

        ## Actual Work

        | Exercise | Actual sets | Actual reps | Load | Actual RPE | Notes |
        | --- | --- | --- | --- | --- | --- |
        | Reverse lunge | 2 | 9, 9 per side | 12 kg | 7, 7 | Two stable working sets completed |
        | Dumbbell floor press | 3 | 11, 10, 9 | 16 kg | 7, 8, 8 | Pause stayed consistent |
      MARKDOWN
    else
      raise ArgumentError, "unknown acceptance session #{number}"
    end
  end

  def integrated_conditioning(performed)
    if performed
      <<~MARKDOWN
        ## Integrated Conditioning

        - Performed?: yes
        - Modality: stationary cycling
        - Prescribed minutes and intensity: 12 minutes at RPE 6
        - Actual minutes and intensity: 12 minutes at RPE 6
        - Credited minutes: 12
        - Total duration impact: added 12 minutes
        - Strength-volume impact: one accessory working set removed
        - Lower-body impact: lunges reduced from 4 to 2 working sets
        - Rationale: moderate cycling replaced lower-body volume
      MARKDOWN
    else
      <<~MARKDOWN
        ## Integrated Conditioning

        - Performed?: no
        - Modality: none
        - Prescribed minutes and intensity: none
        - Actual minutes and intensity: none
        - Credited minutes: 0
        - Total duration impact: none
        - Strength-volume impact: none
        - Lower-body impact: none
        - Rationale: no integrated conditioning was prescribed
      MARKDOWN
    end
  end

  def duration_and_notes(number)
    case number
    when 1
      duration_section(planned: "60 minutes", actual: "58 minutes",
                       recovery: "No pain; normal fatigue and recovery",
                       notes: "Stable first exposure to the new press variation")
    when 2
      duration_section(planned: "60 minutes", actual: "41 minutes",
                       recovery: "No pain; grip fatigue rose earlier than expected",
                       notes: "Stopped after two sets per exercise and chose to repeat B")
    when 3
      duration_section(planned: "60 minutes", actual: "61 minutes",
                       recovery: "No pain; grip recovered before the repeated session",
                       notes: "Completed the repeated B without form loss")
    when 4
      duration_section(planned: "72 minutes", actual: "70 minutes",
                       recovery: "No pain; legs felt ready after the reduced strength volume",
                       notes: "Cycling stayed moderate and did not raise lower-body RPE")
    else
      raise ArgumentError, "unknown acceptance session #{number}"
    end
  end

  def duration_section(planned:, actual:, recovery:, notes:)
    <<~MARKDOWN
      ## Duration and Notes

      - Planned total duration: #{planned}
      - Actual total duration: #{actual}
      - Pain, fatigue, or recovery notes: #{recovery}
      - Other notes: #{notes}
    MARKDOWN
  end

  def assert_plan_contract(root, plan_path)
    plan = File.read(plan_path)
    headers = plan.lines.filter_map do |line|
      cells = markdown_cells(line)
      cells if cells&.first == "Exercise"
    end
    refute_empty headers, "the accepted plan must contain prescribed exercise tables"
    headers.each do |header|
      assert_equal PLANNED_EXERCISE_SCHEMA, header,
                   "planned exercise tables may contain only sets, reps, target RPE, and notes"
    end
    refute_match(/\b\d+(?:[.,]\d+)?\s*(?:kg|lb|lbs|pounds?)\b/i, plan,
                 "the accepted plan must not prescribe a numeric load")

    library_names = read_yaml(root, "data/exercise_library.yaml").fetch("exercises").filter_map do |exercise|
      exercise["name"] if exercise.is_a?(Hash)
    end
    refute_includes library_names, NOVEL_EXERCISE
    assert_includes planned_exercises(plan), NOVEL_EXERCISE
    refute_match(%r{youtube\.com/watch\?v=}, plan)
  end

  def assert_filled_session_logs(root)
    expectations = {
      "01-A.md" => {
        "status" => "completed", "decision" => nil, "position_before" => nil,
        "position_after" => "A", "next_session" => "B", "credited" => true,
        "planned_duration" => "60 minutes", "actual_duration" => "58 minutes"
      },
      "02-B.md" => {
        "status" => "partial", "decision" => "repeat", "position_before" => "A",
        "position_after" => "A", "next_session" => "B", "credited" => false,
        "planned_duration" => "60 minutes", "actual_duration" => "41 minutes"
      },
      "03-B.md" => {
        "status" => "completed", "decision" => nil, "position_before" => "A",
        "position_after" => "B", "next_session" => "C", "credited" => true,
        "planned_duration" => "60 minutes", "actual_duration" => "61 minutes"
      },
      "04-C.md" => {
        "status" => "completed", "decision" => nil, "position_before" => "B",
        "position_after" => "C", "next_session" => "A", "credited" => true,
        "planned_duration" => "72 minutes", "actual_duration" => "70 minutes"
      }
    }

    expectations.each do |filename, expected|
      document = File.read(File.join(root, "blocks", BLOCK, "sessions", filename))
      metadata = document_metadata(document)
      assert_equal expected["status"], metadata.fetch("status"), "#{filename}: wrong status metadata"
      assert_optional_equal(expected["decision"], metadata.fetch("sequence_decision"),
                            "#{filename}: wrong sequence decision metadata")
      assert_optional_equal(expected["position_before"], metadata.fetch("sequence_position_before"),
                            "#{filename}: wrong prior position metadata")
      assert_equal expected["next_session"], metadata.fetch("next_session"),
                   "#{filename}: wrong next-session metadata"
      assert_equal expected["credited"], metadata.fetch("credited_strength_session"),
                   "#{filename}: wrong strength credit"

      lifecycle = section_fields(document, "Lifecycle and Sequence")
      assert_equal "active", lifecycle.fetch("Plan status at time of session")
      assert_equal expected["status"], lifecycle.fetch("Session status")
      assert_equal(expected["decision"] || "not applicable", lifecycle.fetch("Sequence decision"))
      assert_equal expected["position_after"], lifecycle.fetch("Sequence position after this outcome")
      assert_equal expected["next_session"], lifecycle.fetch("Next session template")

      prescribed_rows = markdown_table(document, "Prescribed Work", PLANNED_EXERCISE_SCHEMA)
      actual_rows = markdown_table(document, "Actual Work", ACTUAL_EXERCISE_SCHEMA)
      assert_equal 2, prescribed_rows.length, "#{filename}: prescribed work must list both exercises"
      assert_equal 2, actual_rows.length, "#{filename}: actual work must list both exercises"
      [*prescribed_rows, *actual_rows].each do |row|
        refute row.values.any?(&:empty?), "#{filename}: exercise rows must not contain blank cells"
      end
      actual_rows.each do |row|
        assert_match(/\A\d+(?:[.,]\d+)? kg\z/, row.fetch("Load"),
                     "#{filename}: actual load must be filled and remains permitted")
      end

      optional_cardio = section_fields(document, "Optional Cardio")
      assert_equal "no", optional_cardio.fetch("Performed?")
      assert_equal "none", optional_cardio.fetch("Modality")
      assert_equal "0", optional_cardio.fetch("Minutes")
      assert_equal "none", optional_cardio.fetch("Intensity")
      refute_empty optional_cardio.fetch("Notes")

      integrated = section_fields(document, "Integrated Conditioning")
      %w[Performed? Modality Credited\ minutes Rationale].each do |field|
        refute_empty integrated.fetch(field), "#{filename}: missing integrated field #{field.inspect}"
      end
      [
        "Prescribed minutes and intensity", "Actual minutes and intensity", "Total duration impact",
        "Strength-volume impact", "Lower-body impact"
      ].each do |field|
        refute_empty integrated.fetch(field), "#{filename}: missing integrated field #{field.inspect}"
      end

      duration = section_fields(document, "Duration and Notes")
      assert_equal expected["planned_duration"], duration.fetch("Planned total duration")
      assert_equal expected["actual_duration"], duration.fetch("Actual total duration")
      refute_empty duration.fetch("Pain, fatigue, or recovery notes")
      refute_empty duration.fetch("Other notes")
    end

    partial = File.read(File.join(root, "blocks", BLOCK, "sessions", "02-B.md"))
    assert markdown_table(partial, "Prescribed Work", PLANNED_EXERCISE_SCHEMA).all? { |row|
      row.fetch("Prescribed sets") == "3"
    }
    assert markdown_table(partial, "Actual Work", ACTUAL_EXERCISE_SCHEMA).all? { |row|
      row.fetch("Actual sets") == "2"
    }
  end

  def assert_integrated_cycling(root)
    plan = File.read(File.join(root, "blocks", BLOCK, "plan.md"))
    session = File.read(File.join(root, "blocks", BLOCK, "sessions", "04-C.md"))
    actual_rows = markdown_table(session, "Actual Work", ACTUAL_EXERCISE_SCHEMA)
    reverse_lunge = actual_rows.find { |row| row.fetch("Exercise") == "Reverse lunge" }
    refute_nil reverse_lunge, "integrated C must log its actual reverse-lunge work"
    assert_equal 2, Integer(reverse_lunge.fetch("Actual sets")),
                 "integrated cycling must reduce actual reverse-lunge volume to two working sets"
    assert_equal "12 kg", reverse_lunge.fetch("Load"), "actual logged loads remain allowed"

    plan_fields = section_fields(plan, "Integrated Conditioning")
    assert_equal "C", plan_fields.fetch("Session template")
    assert_equal "stationary cycling", plan_fields.fetch("Modality")
    assert_equal "12 minutes at RPE 6", plan_fields.fetch("Minutes and intensity")
    assert_equal "adds 12 minutes to Template C", plan_fields.fetch("Total-duration impact")
    assert_equal "removes one accessory working set", plan_fields.fetch("Strength-volume impact")
    assert_equal "reduces lunges from 4 to 2 working sets", plan_fields.fetch("Lower-body impact")

    session_fields = section_fields(session, "Integrated Conditioning")
    assert_equal "yes", session_fields.fetch("Performed?")
    assert_equal "stationary cycling", session_fields.fetch("Modality")
    assert_equal "12 minutes at RPE 6", session_fields.fetch("Prescribed minutes and intensity")
    assert_equal "12 minutes at RPE 6", session_fields.fetch("Actual minutes and intensity")
    assert_equal "12", session_fields.fetch("Credited minutes")
    assert_equal "added 12 minutes", session_fields.fetch("Total duration impact")
    assert_equal "one accessory working set removed", session_fields.fetch("Strength-volume impact")
    assert_equal "lunges reduced from 4 to 2 working sets", session_fields.fetch("Lower-body impact")
  end

  def markdown_table(document, heading, expected_schema)
    lines = document.lines
    heading_index = lines.index { |line| line.strip == "## #{heading}" }
    refute_nil heading_index, "session log must include #{heading.inspect}"
    header_index = ((heading_index + 1)...lines.length).find { |index| lines[index].start_with?("|") }
    refute_nil header_index, "#{heading.inspect} must contain a Markdown table"
    headers = markdown_cells(lines.fetch(header_index))
    assert_equal expected_schema, headers, "#{heading.inspect} has the wrong columns"

    lines[(header_index + 2)..].take_while { |line| line.start_with?("|") }.map do |line|
      headers.zip(markdown_cells(line)).to_h
    end
  end

  def section_fields(document, heading)
    lines = document.lines
    heading_index = lines.index { |line| line.strip == "## #{heading}" }
    refute_nil heading_index, "document must include #{heading.inspect}"
    section_lines = lines[(heading_index + 1)..].take_while { |line| !line.match?(/\A##\s+/) }
    section_lines.each_with_object({}) do |line, fields|
      match = line.match(/\A-\s+([^:]+):\s*(.+?)\s*\z/)
      fields[match[1]] = match[2] if match
    end
  end

  def document_metadata(document)
    match = document.match(/\A---[ \t]*\r?\n(?<yaml>.*?)\r?\n---[ \t]*(?:\r?\n|\z)/m)
    refute_nil match, "session log must contain YAML front matter"
    YAML.safe_load(match[:yaml], permitted_classes: [Date], aliases: false)
  end

  def assert_optional_equal(expected, actual, message)
    expected.nil? ? assert_nil(actual, message) : assert_equal(expected, actual, message)
  end

  def planned_exercises(plan)
    plan.lines.filter_map do |line|
      cells = markdown_cells(line)
      next unless cells&.length == 5
      next if cells.first == "Exercise" || cells.all? { |cell| cell.match?(/\A-+\z/) }

      cells.first
    end
  end

  def markdown_cells(line)
    return unless line.start_with?("|") && line.rstrip.end_with?("|")

    line.strip.delete_prefix("|").delete_suffix("|").split("|").map(&:strip)
  end

  def assert_validation(root, expected_codes, label)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, VALIDATOR, root)
    assert_empty stderr, "#{label}: validator wrote to stderr"
    run = ValidationRun.new(output: stdout, status: status)
    assert_equal 0, run.status.exitstatus, "#{label}: #{run.output}"
    assert_equal expected_codes, run.codes, "#{label}: unexpected validator diagnostics"
  end

  def assert_state(root, position:, next_session:, label:)
    state = read_yaml(root, "_system/state/current.yaml")
    if position.nil?
      assert_nil state["sequence_position"], "#{label}: wrong sequence position"
    else
      assert_equal position, state["sequence_position"], "#{label}: wrong sequence position"
    end
    assert_equal next_session, state["next_session"], "#{label}: wrong next session"
  end

  def session_filenames(root)
    Dir.glob(File.join(root, "blocks", BLOCK, "sessions", "*.md")).map { |path| File.basename(path) }.sort
  end

  def read_yaml(root, relative_path)
    YAML.safe_load(File.read(File.join(root, relative_path)), permitted_classes: [Date], aliases: false)
  end

  def write_yaml(root, relative_path, value)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, YAML.dump(value))
  end
end
