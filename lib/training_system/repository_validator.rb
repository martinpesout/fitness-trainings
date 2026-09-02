# frozen_string_literal: true

require "yaml"
require "training_system/sequence"
require "training_system/yaml_loader"

module TrainingSystem
  Diagnostic = Struct.new(:severity, :code, :path, :message, keyword_init: true)

  class RepositoryValidator
    CORE_FILES = %w[
      data/profile.yaml
      data/equipment.yaml
      data/preferences.md
      data/exercise_library.yaml
      data/coaching_rules.md
      data/history_summary.md
      calendar/exceptions.yaml
      _system/state/current.yaml
      _system/templates/plan.md
      _system/templates/session-log.md
      _system/templates/block-review.md
    ].freeze
    PLAN_HEADINGS = [
      "Block Intent", "Lifecycle", "Duration and Session Target", "Shared Rules",
      "Session Templates", "Progression", "Optional Cardio", "Integrated Conditioning",
      "Approved Changes"
    ].freeze
    PLAN_STATUSES = %w[draft approved active completed].freeze
    REVIEW_HEADINGS = [
      "Adherence", "RPE and Progress", "Novelty", "Fatigue and Pain", "Cardio",
      "Next-Block Recommendation"
    ].freeze
    FINAL_SESSION_STATUSES = %w[completed partial aborted].freeze
    SESSION_STATUSES = ["in_progress", *FINAL_SESSION_STATUSES].freeze
    EQUIPMENT_REVIEW_STATUSES = %w[needs_input confirmed].freeze
    HEALTH_REVIEW_STATUSES = %w[needs_review confirmed].freeze
    PLAN_INTEGRATED_STATUSES = %w[none planned].freeze
    PLANNED_WORK_HEADERS = ["Exercise", "Prescribed sets", "Prescribed reps", "Target RPE", "Notes"].freeze
    ACTUAL_WORK_HEADERS = ["Exercise", "Actual sets", "Actual reps", "Load", "Actual RPE", "Notes"].freeze
    SESSION_HEADINGS = [
      "Lifecycle and Sequence", "Prescribed Work", "Actual Work", "Optional Cardio",
      "Integrated Conditioning", "Duration and Notes"
    ].freeze
    PLAN_INTEGRATED_BASE_FIELDS = ["Status", "Rationale"].freeze
    PLAN_INTEGRATED_DETAIL_FIELDS = [
      "Session template", "Minutes and intensity", "Total-duration impact",
      "Strength-volume impact", "Lower-body impact"
    ].freeze
    SESSION_REQUIRED_FIELDS = {
      "Lifecycle and Sequence" => [
        "Plan status at time of session", "Session status", "Sequence decision",
        "Sequence position after this outcome", "Next session template"
      ],
      "Optional Cardio" => ["Performed?", "Minutes", "Intensity"],
      "Integrated Conditioning" => [
        "Performed?", "Prescribed minutes and intensity", "Actual minutes and intensity",
        "Credited minutes", "Total duration impact", "Strength-volume impact",
        "Lower-body impact", "Rationale"
      ],
      "Duration and Notes" => [
        "Planned total duration", "Actual total duration", "Pain, fatigue, or recovery notes",
        "Other notes"
      ]
    }.freeze
    BLOCK_DIRECTORY = /\A\d{4}-(?:0[1-9]|1[0-2])-block-(\d{3})\z/
    SESSION_FILENAME = /\A(\d{2})-(.+)\.md\z/
    NUMERIC_LOAD = /\b\d+(?:[.,]\d+)?\s*(?:kg|kgs?|lb|lbs|pounds?)\b/i

    def initialize(root)
      @root = File.expand_path(root)
      @diagnostics = []
    end

    def call
      CORE_FILES.each { |path| require_file(path) }
      profile = yaml_mapping("data/profile.yaml")
      equipment = yaml_mapping("data/equipment.yaml")
      yaml_mapping("data/exercise_library.yaml")
      yaml_mapping("calendar/exceptions.yaml")
      current = yaml_mapping("_system/state/current.yaml")

      validate_onboarding(profile, equipment)
      sequence = validate_current(current)
      validate_blocks(current, sequence)
      @diagnostics.sort_by { |item| [item.path, item.severity, item.code] }
    end

    private

    def require_file(path)
      error("missing_core_file", path, "Required file is missing") unless File.file?(absolute(path))
    end

    def yaml_mapping(path)
      return nil unless File.file?(absolute(path))

      value = YamlLoader.load(absolute(path))
      unless value.is_a?(Hash)
        error("invalid_yaml_type", path, "YAML root must be a mapping")
        return nil
      end
      value
    rescue DataError => exception
      code = exception.message.include?("must contain a mapping or list") ? "invalid_yaml_type" : "invalid_yaml"
      error(code, path, exception.message)
      nil
    end

    def validate_onboarding(profile, equipment)
      equipment_status_present, equipment_status = required_field(equipment, "review_status", "data/equipment.yaml.review_status")
      if equipment_status_present && !EQUIPMENT_REVIEW_STATUSES.include?(equipment_status)
        error("invalid_equipment_review_status", "data/equipment.yaml.review_status", "review_status must be needs_input or confirmed")
      elsif equipment_status == "needs_input"
        warning("equipment_needs_input", "data/equipment.yaml.review_status", "Equipment review still needs user input")
      end

      health_present, health = required_field(profile, "health", "data/profile.yaml.health")
      return unless health_present

      unless health.is_a?(Hash)
        error("invalid_field_type", "data/profile.yaml.health", "health must be a mapping")
        return
      end

      health_status_present, health_status = required_field(health, "review_status", "data/profile.yaml.health.review_status")
      if health_status_present && !HEALTH_REVIEW_STATUSES.include?(health_status)
        error("invalid_health_review_status", "data/profile.yaml.health.review_status", "review_status must be needs_review or confirmed")
      elsif health_status == "needs_review"
        warning("health_needs_review", "data/profile.yaml.health.review_status", "Health review still needs confirmation")
      end
    end

    def required_field(mapping, field, path)
      return [false, nil] unless mapping.is_a?(Hash)
      return [true, mapping[field]] if mapping.key?(field)

      error("missing_required_field", path, "Required field is missing")
      [false, nil]
    end

    def validate_current(current)
      return nil unless current.is_a?(Hash)

      sequence = current["default_sequence"]
      begin
        Sequence.next(sequence: sequence, position: nil)
      rescue ArgumentError => exception
        error("invalid_default_sequence", "_system/state/current.yaml.default_sequence", exception.message)
        return nil
      end

      validate_current_sequence(current, sequence) if current["active_block"].nil?
      sequence
    end

    def validate_current_sequence(current, sequence)
      expected = Sequence.next(sequence: sequence, position: current["sequence_position"])
      next_session = current["next_session"]
      return if next_session.is_a?(String) && next_session == expected

      error("mismatched_next_session", "_system/state/current.yaml.next_session", "Expected #{expected.inspect} from the rolling sequence")
    rescue ArgumentError => exception
      error("invalid_sequence_position", "_system/state/current.yaml.sequence_position", exception.message)
    end

    def validate_blocks(current, default_sequence)
      blocks = Dir.glob(absolute("blocks/*")).select { |path| File.directory?(path) }.sort
      block_records = {}
      blocks.each do |block_path|
        relative = relative_path(block_path)
        validate_block_directory(relative)
        plan = plan_metadata(relative)
        next unless plan

        sequence = validate_plan(relative, plan)
        replay = validate_sessions(relative, plan, sequence) if sequence
        validate_completed_review(relative, plan) if plan["status"] == "completed"
        block_records[File.basename(block_path)] = { path: relative, plan: plan, sequence: sequence, replay: replay }
      end
      validate_active_block(current, blocks, block_records) if current.is_a?(Hash)
      default_sequence
    end

    def validate_block_directory(block)
      return if BLOCK_DIRECTORY.match?(File.basename(block))

      error("invalid_block_directory_name", block, "Block directory must use YYYY-MM-block-NNN with a valid month")
    end

    def validate_active_block(current, block_paths, block_records)
      active = current["active_block"]
      return if active.nil?

      unless active.is_a?(String) && !active.empty?
        error("invalid_field_type", "_system/state/current.yaml.active_block", "active_block must be a block directory name or null")
        return
      end
      block = block_paths.find { |path| File.basename(path) == active }
      unless block
        error("missing_active_block", "_system/state/current.yaml.active_block", "Active block directory does not exist")
        return
      end
      record = block_records[active]
      return unless record

      plan = record[:plan]

      if plan["status"] == "draft"
        error("active_plan_is_draft", "#{relative_path(block)}/plan.md.status", "An active block cannot use a draft plan")
      end
      unless plan["status"] == "active"
        error("active_plan_status_mismatch", "#{relative_path(block)}/plan.md.status", "An active block requires plan status active")
      end
      unless current["plan_status"] == "active"
        error("active_state_plan_status_mismatch", "_system/state/current.yaml.plan_status", "An active block requires state plan_status active")
      end
      if positive_integer?(plan["block_number"]) && current["block_number"] != plan["block_number"]
        error("mismatched_active_block_number", "_system/state/current.yaml.block_number", "State block_number must match the active plan")
      end

      validate_active_replay(current, record[:replay]) if record[:sequence] && record[:replay]
    end

    def validate_active_replay(current, replay)
      unless current["sequence_position"] == replay[:position]
        error("mismatched_active_sequence_position", "_system/state/current.yaml.sequence_position", "Expected #{replay[:position].inspect} from active block session history")
      end
      unless current["next_session"] == replay[:next_session]
        error("mismatched_next_session", "_system/state/current.yaml.next_session", "Expected #{replay[:next_session].inspect} from active block session history")
      end
    end

    def plan_metadata(block)
      path = "#{block}/plan.md"
      return missing_plan(path) unless File.file?(absolute(path))

      front_matter(absolute(path), path)
    end

    def validate_completed_review(block, plan)
      path = "#{block}/review.md"
      unless File.file?(absolute(path))
        error("missing_block_review", path, "A completed plan requires review.md")
        return
      end

      review = front_matter(absolute(path), path)
      return unless review

      block_number = review["block_number"]
      if !positive_integer?(block_number)
        error("invalid_review_block_number", "#{path}.block_number", "Review block_number must be a positive integer")
      elsif block_number != plan["block_number"]
        error("mismatched_review_block_number", "#{path}.block_number", "Review block_number must match the plan")
      end
      unless review["plan_status"] == "completed"
        error("invalid_review_plan_status", "#{path}.plan_status", "Review plan_status must be completed")
      end
      unless review["review_date"].is_a?(Date)
        error("invalid_review_date", "#{path}.review_date", "Review review_date must be a valid date")
      end

      headings = File.read(absolute(path)).scan(/^##[ \t]+(.+?)(?:[ \t]+#+)?[ \t]*$/).flatten.map(&:strip)
      REVIEW_HEADINGS.each do |heading|
        error("missing_review_heading", path, "Review is missing H2 heading #{heading.inspect}") unless headings.include?(heading)
      end
    rescue SystemCallError => exception
      error("unreadable_file", path, exception.message)
    end

    def missing_plan(path)
      error("missing_plan", path, "Block is missing plan.md")
      nil
    end

    def front_matter(file, display_path)
      contents = File.read(file)
      match = contents.match(/\A---[ \t]*\r?\n(?<yaml>.*?)\r?\n---[ \t]*(?:\r?\n|\z)/m)
      unless match
        error("missing_front_matter", display_path, "Document is missing YAML front matter")
        return nil
      end
      value = YAML.safe_load(match[:yaml], permitted_classes: [Date], permitted_symbols: [], aliases: false)
      unless value.is_a?(Hash)
        error("invalid_metadata_type", display_path, "YAML front matter must be a mapping")
        return nil
      end
      value
    rescue Psych::Exception, ArgumentError => exception
      error("invalid_metadata", display_path, "Invalid YAML front matter: #{exception.message}")
      nil
    rescue SystemCallError => exception
      error("unreadable_file", display_path, exception.message)
      nil
    end

    def validate_plan(block, plan)
      path = "#{block}/plan.md"
      document = File.read(absolute(path))
      status = plan["status"]
      error("invalid_plan_status", "#{path}.status", "Plan status must be one of #{PLAN_STATUSES.join(', ')}") unless PLAN_STATUSES.include?(status)

      block_number = plan["block_number"]
      unless positive_integer?(block_number)
        error("invalid_plan_block_number", "#{path}.block_number", "Plan block_number must be a positive integer")
      end
      directory_number = File.basename(block)[/block-(\d{3})\z/, 1]&.to_i
      if positive_integer?(block_number) && directory_number && block_number != directory_number
        error("mismatched_plan_block_number", "#{path}.block_number", "Plan block_number must match the block directory suffix")
      end

      duration = plan["planned_duration_weeks"]
      unless duration.is_a?(Integer) && (3..6).cover?(duration)
        error("invalid_block_duration", "#{path}.planned_duration_weeks", "Block duration must be an integer from 3 to 6")
      end

      frequency = plan["weekly_strength_frequency"]
      target = plan["target_strength_sessions"]
      unless positive_integer?(frequency)
        error("invalid_weekly_strength_frequency", "#{path}.weekly_strength_frequency", "Weekly strength frequency must be a positive integer")
      end
      unless positive_integer?(target)
        error("invalid_target_strength_sessions", "#{path}.target_strength_sessions", "Target strength sessions must be a positive integer")
      end
      if duration.is_a?(Integer) && positive_integer?(frequency) && positive_integer?(target) && target != duration * frequency
        error("mismatched_target_strength_sessions", "#{path}.target_strength_sessions", "Target must equal duration times weekly strength frequency")
      end

      headings = document.scan(/^\#{1,6}[ \t]+(.+?)(?:[ \t]+\#+)?[ \t]*$/).flatten.map(&:strip)
      PLAN_HEADINGS.each do |heading|
        error("missing_plan_heading", path, "Plan is missing heading #{heading.inspect}") unless headings.include?(heading)
      end

      sequence = plan["sequence"]
      begin
        Sequence.next(sequence: sequence, position: nil)
        sequence.each do |template|
          heading = "Template #{template}"
          if headings.include?(heading)
            validate_plan_template(path, document, heading)
          else
            error("missing_template_section", path, "Plan is missing heading #{heading.inspect}")
          end
        end
        validate_plan_integrated_conditioning(path, document)
        sequence
      rescue ArgumentError => exception
        error("invalid_plan_sequence", "#{path}.sequence", exception.message)
        nil
      end
    rescue SystemCallError => exception
      error("unreadable_file", path, exception.message)
      nil
    end

    def validate_sessions(block, plan, sequence)
      entries = Dir.glob(absolute("#{block}/sessions/*.md")).sort.filter_map do |file|
        path = relative_path(file)
        metadata = front_matter(file, path)
        next unless metadata

        validate_session_content(path, File.read(file))
        filename = validate_session_filename(path, metadata)
        validate_session_status(path, metadata)
        validate_session_template(path, metadata, sequence)
        validate_session_prior_position(path, metadata, sequence)
        validate_session_block_number(path, metadata, plan)
        { path: path, metadata: metadata, number: filename&.first }
      end

      canonical_entries = entries.select { |entry| entry[:number] }.sort_by { |entry| [entry[:number], entry[:path]] }
      validate_session_number_chain(block, canonical_entries)
      replay_sessions(canonical_entries, sequence)
    end

    def validate_plan_template(path, document, heading)
      body = section_body(document, heading)
      if body.match?(NUMERIC_LOAD)
        error("numeric_planned_load", path, "#{heading.inspect} cannot prescribe a numeric kg or lb load")
      end
      table = markdown_table(body)
      unless table
        error("missing_planned_work_table", path, "#{heading.inspect} requires a planned-work Markdown table")
        return
      end

      headers, rows = table
      if headers.any? { |header| header.match?(/load|weight|\bkg\b|\blbs?\b/i) }
        error("planned_load_column", path, "#{heading.inspect} planned-work headers cannot contain load or weight")
      end
      unless headers == PLANNED_WORK_HEADERS
        error("invalid_planned_work_schema", path, "#{heading.inspect} must use the exact planned-work headers")
      end
      if rows.empty? || rows.all? { |row| row.all?(&:empty?) }
        error("empty_planned_work_table", path, "#{heading.inspect} planned-work table must contain a filled row")
      elsif rows.any? { |row| row.length != headers.length || row.any?(&:empty?) }
        error("blank_planned_work_cell", path, "#{heading.inspect} planned-work rows must fill every cell")
      end
    end

    def validate_plan_integrated_conditioning(path, document)
      body = section_body(document, "Integrated Conditioning")
      fields = markdown_fields(body)
      PLAN_INTEGRATED_BASE_FIELDS.each do |field|
        next if fields.key?(field) && !fields[field].empty?

        error("missing_integrated_conditioning_field", path, "Integrated Conditioning requires nonblank #{field.inspect}")
      end

      status = fields["Status"]
      return if status.nil? || status.empty?

      unless PLAN_INTEGRATED_STATUSES.include?(status)
        error("invalid_integrated_conditioning_status", path, "Integrated Conditioning status must be none or planned")
        return
      end
      return if status == "none"

      PLAN_INTEGRATED_DETAIL_FIELDS.each do |field|
        next if fields.key?(field) && !fields[field].empty?

        error("missing_integrated_conditioning_field", path, "Planned Integrated Conditioning requires nonblank #{field.inspect}")
      end
    end

    def validate_session_content(path, document)
      headings = h2_headings(document)
      SESSION_HEADINGS.each do |heading|
        error("missing_session_heading", path, "Session is missing H2 heading #{heading.inspect}") unless headings.include?(heading)
      end

      validate_session_work_table(path, document, "Prescribed Work", PLANNED_WORK_HEADERS, "invalid_prescribed_work_schema")
      validate_session_work_table(path, document, "Actual Work", ACTUAL_WORK_HEADERS, "invalid_actual_work_schema")

      SESSION_REQUIRED_FIELDS.each do |heading, required_fields|
        fields = markdown_fields(section_body(document, heading))
        required_fields.each do |field|
          next if fields.key?(field) && !fields[field].empty?

          error("missing_session_field", path, "#{heading.inspect} requires nonblank #{field.inspect}")
        end
      end
    end

    def validate_session_work_table(path, document, heading, expected_headers, schema_code)
      table = markdown_table(section_body(document, heading))
      unless table
        error("missing_session_work_table", path, "#{heading.inspect} requires a Markdown table")
        return
      end

      headers, rows = table
      error(schema_code, path, "#{heading.inspect} must use the exact table headers") unless headers == expected_headers
      if rows.empty? || rows.all? { |row| row.all?(&:empty?) }
        error("empty_session_work_table", path, "#{heading.inspect} must contain a filled row")
      elsif rows.any? { |row| row.length != headers.length || row.any?(&:empty?) }
        error("blank_session_work_cell", path, "#{heading.inspect} rows must fill every cell")
      end
    end

    def validate_session_filename(path, metadata)
      match = File.basename(path).match(SESSION_FILENAME)
      unless match
        error("invalid_session_filename", path, "Session filename must use NN-TEMPLATE.md")
        return nil
      end
      number, template = match.captures
      unless metadata["session_number"] == number.to_i && metadata["template"] == template
        error("session_filename_mismatch", path, "Filename must match session_number and template metadata")
      end

      [number.to_i, template]
    end

    def validate_session_status(path, metadata)
      status = metadata["status"]
      unless SESSION_STATUSES.include?(status)
        error("invalid_session_status", "#{path}.status", "Session status must be in_progress, completed, partial, or aborted")
        return
      end
      decision = metadata["sequence_decision"]
      if %w[partial aborted].include?(status) && !Sequence::DECISIONS.include?(decision)
        error("missing_sequence_decision", "#{path}.sequence_decision", "Partial and aborted sessions require repeat or advance")
      elsif %w[in_progress completed].include?(status) && !decision.nil?
        error("invalid_sequence_decision", "#{path}.sequence_decision", "In-progress and completed sessions must not specify a sequence decision")
      end
      if status == "in_progress" && metadata["credited_strength_session"] != false
        error("invalid_in_progress_credit", "#{path}.credited_strength_session", "An in-progress session cannot receive strength-session credit")
      end
    end

    def validate_session_template(path, metadata, sequence)
      template = metadata["template"]
      unless template.is_a?(String) && sequence.include?(template)
        error("unknown_session_template", "#{path}.template", "Session template is not in the plan sequence")
      end
    end

    def validate_session_prior_position(path, metadata, sequence)
      position = metadata["sequence_position_before"]
      unless position.nil? || (position.is_a?(String) && sequence.include?(position))
        error("invalid_sequence_position_before", "#{path}.sequence_position_before", "Position must be a sequence template or null")
        return
      end
      template = metadata["template"]
      return unless template.is_a?(String) && sequence.include?(template)

      expected = Sequence.next(sequence: sequence, position: position)
      return if template == expected

      error("mismatched_session_template", "#{path}.template", "Expected #{expected.inspect} from the prior sequence position")
    end

    def validate_session_block_number(path, metadata, plan)
      return if metadata["block_number"] == plan["block_number"]

      error("mismatched_session_block_number", "#{path}.block_number", "Session block_number must match the plan")
    end

    def validate_session_number_chain(block, entries)
      numbers = entries.map { |entry| entry[:number] }
      if numbers.uniq.length != numbers.length
        error("duplicate_session_number", "#{block}/sessions", "Session numbers must be unique")
      end
      expected = (1..numbers.length).to_a
      unless numbers.uniq.sort == expected
        error("noncontiguous_session_numbers", "#{block}/sessions", "Session numbers must be contiguous from 1")
      end
    end

    def replay_sessions(entries, sequence)
      in_progress_index = entries.index { |entry| entry[:metadata]["status"] == "in_progress" }
      if in_progress_index && in_progress_index < entries.length - 1
        following_entry = entries.fetch(in_progress_index + 1)
        error("session_after_in_progress", following_entry[:path], "No session can follow an in-progress session")
      end

      position = nil
      entries.each do |entry|
        path = entry[:path]
        metadata = entry[:metadata]
        prior = metadata["sequence_position_before"]
        unless prior == position
          error("broken_session_chain", "#{path}.sequence_position_before", "Expected #{position.inspect} from the previous session outcome")
        end

        template = metadata["template"]
        status = metadata["status"]
        decision = metadata["sequence_decision"]
        if status == "in_progress"
          expected_next = Sequence.next(sequence: sequence, position: position)
          unless metadata["next_session"] == expected_next
            error("mismatched_next_session", "#{path}.next_session", "Expected #{expected_next.inspect} while the session remains in progress")
          end
          next
        end

        valid_outcome = FINAL_SESSION_STATUSES.include?(status) &&
          (status == "completed" || Sequence::DECISIONS.include?(decision))
        valid_template = sequence.include?(template)
        if valid_outcome && valid_template
          position = template unless %w[partial aborted].include?(status) && decision == "repeat"
          expected_next = Sequence.next(sequence: sequence, position: position)
          unless metadata["next_session"] == expected_next
            error("mismatched_next_session", "#{path}.next_session", "Expected #{expected_next.inspect} from the replayed outcome")
          end
        end
      end
      { position: position, next_session: Sequence.next(sequence: sequence, position: position) }
    end

    def section_body(document, title)
      lines = document.lines
      heading_index = lines.index do |line|
        match = line.match(/\A(\#{1,6})[ \t]+(.+?)(?:[ \t]+\#+)?[ \t]*\r?\n?\z/)
        match && match[2].strip == title
      end
      return "" unless heading_index

      level = lines.fetch(heading_index)[/\A#+/].length
      end_index = ((heading_index + 1)...lines.length).find do |index|
        match = lines.fetch(index).match(/\A(\#{1,6})[ \t]+/)
        match && match[1].length <= level
      end || lines.length
      lines[(heading_index + 1)...end_index].join
    end

    def h2_headings(document)
      document.scan(/^##[ \t]+([^#\r\n].*?)(?:[ \t]+#+)?[ \t]*$/).flatten.map(&:strip)
    end

    def markdown_fields(section)
      section.lines.each_with_object({}) do |line, fields|
        match = line.match(/\A-\s+(.+?):\s*(.*?)\s*\r?\n?\z/)
        fields[match[1].strip] = match[2].strip if match
      end
    end

    def markdown_table(section)
      lines = section.lines
      header_index = lines.index { |line| markdown_cells(line) }
      return nil unless header_index

      headers = markdown_cells(lines.fetch(header_index))
      separator = markdown_cells(lines.fetch(header_index + 1, ""))
      return nil unless separator && separator.length == headers.length
      return nil unless separator.all? { |cell| cell.match?(/\A:?-{3,}:?\z/) }

      rows = lines[(header_index + 2)..].to_a.take_while { |line| markdown_cells(line) }.map do |line|
        markdown_cells(line)
      end
      [headers, rows]
    end

    def markdown_cells(line)
      stripped = line.strip
      return nil unless stripped.start_with?("|") && stripped.end_with?("|")

      stripped.delete_prefix("|").delete_suffix("|").split("|", -1).map(&:strip)
    end

    def absolute(path)
      File.join(@root, path)
    end

    def relative_path(path)
      path.delete_prefix("#{@root}/")
    end

    def positive_integer?(value)
      value.is_a?(Integer) && value.positive?
    end

    def error(code, path, message)
      @diagnostics << Diagnostic.new(severity: "error", code: code, path: path, message: message)
    end

    def warning(code, path, message)
      @diagnostics << Diagnostic.new(severity: "warning", code: code, path: path, message: message)
    end
  end
end
