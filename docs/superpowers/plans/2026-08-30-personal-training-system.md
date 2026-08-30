# Personal Training System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current placeholder layout with a validated, block-oriented personal training system that keeps structured source data in YAML and human-readable plans, logs, and reviews in Markdown.

**Architecture:** Stable facts live under `data/`, calendar exceptions under `calendar/`, and the active pointer under `state/current.yaml`. Each training block owns its approved plan, actual session logs, and review. A small dependency-free Ruby validator checks structural invariants while `AGENTS.md` governs semantic coaching decisions and the human approval lifecycle.

**Tech Stack:** Markdown, YAML, Ruby 3.3 standard library (`yaml`, `date`, `optparse`, `minitest`), Git

**Spec:** `docs/superpowers/specs/2026-08-30-personal-training-system-design.md`

## Global Constraints

- Use local YAML and Markdown files. Do not add a database, web app, mobile app, wearable integration, or automatic device import.
- Default to a four-week review horizon, but allow a justified `planned_duration_weeks` value from 3 through 6.
- Default to a rolling `[A, B, C]` strength sequence, but keep the sequence configurable per block.
- A canceled date does not advance the strength sequence. A partial session advances only after an explicit `repeat` or `advance` decision.
- Do not prescribe exact working weights in `plan.md`; prescribe rep ranges and target RPE. Actual loads belong in session logs.
- Treat the exercise library as memory, not a whitelist. New exercises are allowed when marked and justified.
- For an exercise without a stored verified video, use `https://www.youtube.com/results?search_query=NÁZEV+CVIKU+form`. Never invent a `youtube.com/watch?v=` URL.
- Optional cardio is not an adherence requirement. Integrated conditioning must disclose longer duration and its effect on lower-body strength volume and nearby sessions.
- A plan remains `draft` until the user explicitly approves it. Approved content is not silently rewritten; later changes are dated amendments.
- Preserve unrelated and user-owned working-tree files.
- Do not execute any `git commit` step until the user has reviewed the complete implementation diff and explicitly approved committing it. During execution, leave all implementation changes uncommitted.

---

## Target file map

### Runtime and tests

- `bin/validate` — command-line entry point; exits nonzero on validation errors.
- `lib/training_system/yaml_loader.rb` — safe YAML loading with path-aware errors.
- `lib/training_system/plan_document.rb` — parses YAML front matter and Markdown headings.
- `lib/training_system/sequence.rb` — pure rolling-sequence decisions.
- `lib/training_system/repository_validator.rb` — validates core files, plan lifecycle, and active-block consistency.
- `test/test_helper.rb` — Minitest setup and temporary repository helpers.
- `test/yaml_loader_test.rb` — YAML parser behavior.
- `test/plan_document_test.rb` — plan front matter and required headings.
- `test/sequence_test.rb` — missed-date and partial-session behavior.
- `test/repository_validator_test.rb` — end-to-end validation scenarios.

### Canonical source data

- `data/profile.yaml` — goals, time budget, default frequency, logging preference, and review-needed health state.
- `data/equipment.yaml` — available equipment; initially explicit `needs_user_input`, never invented values.
- `data/preferences.md` — likes, dislikes, desired experiments, and variety preference.
- `data/exercise_library.yaml` — known exercise metadata; initially empty except migrated verified entries.
- `data/coaching_rules.md` — durable coaching contract derived from the approved spec.
- `data/history_summary.md` — confirmed insights from future completed blocks.
- `calendar/exceptions.yaml` — dated no-training or light-only periods.
- `state/current.yaml` — active block pointer and next strength template.

### Block documents

- `templates/plan.md` — draft block template.
- `templates/session-log.md` — actual strength-session template.
- `templates/block-review.md` — end-of-block review template.
- `blocks/.gitkeep` — keeps the empty canonical block directory until the first approved plan exists.

### Workflow documentation and archive

- `AGENTS.md` — authoritative generation, approval, logging, and review instructions.
- `CLAUDE.md` — retains only the `@AGENTS.md` import.
- `README.md` — user workflow and repository map.
- `ONBOARDING.md` — imports old prescribed plans as inspiration, never as actual performance.
- `archive/former-coach/raw/README.md` — location and immutability rule for former-coach exports.
- `archive/former-coach/summary.md` — confirmed findings and explicitly labeled hypotheses.

### Obsolete paths removed after content migration

- `data/coach_summary.md`
- `data/exercise_library.md`
- `history/_TEMPLATE.md`
- `history/blocks_archive.md`
- `history/coach_archive/README.md`
- `plans/.gitkeep`
- `state/periodization.yaml`

---

### Task 1: Safe YAML and plan-document readers

**Files:**
- Create: `lib/training_system/yaml_loader.rb`
- Create: `lib/training_system/plan_document.rb`
- Create: `test/test_helper.rb`
- Create: `test/yaml_loader_test.rb`
- Create: `test/plan_document_test.rb`

**Interfaces:**
- Consumes: filesystem paths containing UTF-8 YAML or Markdown with YAML front matter.
- Produces: `TrainingSystem::YamlLoader.load(path) -> Hash | Array`.
- Produces: `TrainingSystem::PlanDocument.new(path)`, with `metadata -> Hash`, `headings -> Array<String>`, and `require_headings(*names) -> Array<String>`.
- Produces: `TrainingSystem::DataError`, carrying the source path in its message.

- [ ] **Step 1: Add the shared Minitest helper**

Create `test/test_helper.rb`:

```ruby
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

module RepositoryFixture
  def with_repository
    Dir.mktmpdir("training-system-test") do |root|
      yield root
    end
  end

  def write(root, relative_path, content)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content, encoding: "UTF-8")
    path
  end
end
```

- [ ] **Step 2: Write failing YAML-loader tests**

Create `test/yaml_loader_test.rb`:

```ruby
# frozen_string_literal: true

require_relative "test_helper"
require "training_system/yaml_loader"

class YamlLoaderTest < Minitest::Test
  include RepositoryFixture

  def test_loads_mapping_with_date
    with_repository do |root|
      path = write(root, "data.yaml", "version: 1\nstarts_on: 2026-09-01\n")
      data = TrainingSystem::YamlLoader.load(path)

      assert_equal 1, data.fetch("version")
      assert_equal Date.new(2026, 9, 1), data.fetch("starts_on")
    end
  end

  def test_rejects_scalar_document
    with_repository do |root|
      path = write(root, "data.yaml", "just text\n")

      error = assert_raises(TrainingSystem::DataError) do
        TrainingSystem::YamlLoader.load(path)
      end
      assert_includes error.message, "data.yaml"
      assert_includes error.message, "mapping or list"
    end
  end

  def test_wraps_yaml_syntax_error_with_path
    with_repository do |root|
      path = write(root, "broken.yaml", "items: [\n")

      error = assert_raises(TrainingSystem::DataError) do
        TrainingSystem::YamlLoader.load(path)
      end
      assert_includes error.message, "broken.yaml"
    end
  end
end
```

- [ ] **Step 3: Run the YAML tests and verify the red state**

Run: `ruby -Itest test/yaml_loader_test.rb`

Expected: FAIL with `cannot load such file -- training_system/yaml_loader`.

- [ ] **Step 4: Implement the safe YAML loader**

Create `lib/training_system/yaml_loader.rb`:

```ruby
# frozen_string_literal: true

require "yaml"
require "date"

module TrainingSystem
  class DataError < StandardError; end

  module YamlLoader
    module_function

    def load(path)
      data = YAML.safe_load_file(
        path,
        permitted_classes: [Date],
        permitted_symbols: [],
        aliases: false
      )
      return data if data.is_a?(Hash) || data.is_a?(Array)

      raise DataError, "#{path}: expected a YAML mapping or list"
    rescue Psych::Exception => error
      raise DataError, "#{path}: invalid YAML: #{error.message}"
    end
  end
end
```

- [ ] **Step 5: Run the YAML tests and verify the green state**

Run: `ruby -Itest test/yaml_loader_test.rb`

Expected: 3 runs, 0 failures, 0 errors.

- [ ] **Step 6: Write failing plan-document tests**

Create `test/plan_document_test.rb`:

```ruby
# frozen_string_literal: true

require_relative "test_helper"
require "training_system/plan_document"

class PlanDocumentTest < Minitest::Test
  include RepositoryFixture

  VALID_PLAN = <<~MARKDOWN
    ---
    block: 2026-09-block-001
    status: draft
    planned_duration_weeks: 4
    session_sequence: [A, B, C]
    target_strength_sessions: 12
    ---
    # Záměr bloku
    ## Trénink A
    ## Trénink B
    ## Trénink C
    ## Volitelné kardio
  MARKDOWN

  def test_parses_metadata_and_headings
    with_repository do |root|
      document = TrainingSystem::PlanDocument.new(write(root, "plan.md", VALID_PLAN))

      assert_equal "draft", document.metadata.fetch("status")
      assert_equal %w[A B C], document.metadata.fetch("session_sequence")
      assert_includes document.headings, "Záměr bloku"
      assert_includes document.headings, "Trénink C"
    end
  end

  def test_reports_missing_required_headings
    with_repository do |root|
      document = TrainingSystem::PlanDocument.new(write(root, "plan.md", VALID_PLAN))

      assert_equal ["Progrese během bloku"], document.require_headings(
        "Záměr bloku",
        "Progrese během bloku"
      )
    end
  end

  def test_rejects_document_without_front_matter
    with_repository do |root|
      path = write(root, "plan.md", "# Záměr bloku\n")
      error = assert_raises(TrainingSystem::DataError) do
        TrainingSystem::PlanDocument.new(path)
      end

      assert_includes error.message, "YAML front matter"
    end
  end
end
```

- [ ] **Step 7: Run the plan-document tests and verify the red state**

Run: `ruby -Itest test/plan_document_test.rb`

Expected: FAIL with `cannot load such file -- training_system/plan_document`.

- [ ] **Step 8: Implement the plan-document reader**

Create `lib/training_system/plan_document.rb`:

```ruby
# frozen_string_literal: true

require "yaml"
require "date"
require_relative "yaml_loader"

module TrainingSystem
  class PlanDocument
    FRONT_MATTER = /\A---\s*\n(?<yaml>.*?)\n---\s*\n/m

    attr_reader :metadata, :headings

    def initialize(path)
      @path = path
      @text = File.read(path, encoding: "UTF-8")
      match = FRONT_MATTER.match(@text)
      raise DataError, "#{path}: missing YAML front matter" unless match

      @metadata = parse_metadata(match[:yaml])
      @headings = @text.scan(/^\#{1,6}\s+(.+?)\s*$/).flatten
    end

    def require_headings(*names)
      names.reject { |name| headings.include?(name) }
    end

    private

    def parse_metadata(yaml)
      data = YAML.safe_load(
        yaml,
        permitted_classes: [Date],
        permitted_symbols: [],
        aliases: false
      )
      raise DataError, "#{@path}: front matter must be a YAML mapping" unless data.is_a?(Hash)

      data
    rescue Psych::Exception => error
      raise DataError, "#{@path}: invalid front matter: #{error.message}"
    end
  end
end
```

- [ ] **Step 9: Run all Task 1 tests**

Run: `ruby -Itest -e 'Dir["test/{yaml_loader,plan_document}_test.rb"].sort.each { |file| require File.expand_path(file) }'`

Expected: 6 runs, 0 failures, 0 errors.

- [ ] **Step 10: Commit after the complete-diff approval gate**

Do not run this during normal implementation. After the user approves the complete implementation diff:

```bash
git add lib/training_system/yaml_loader.rb lib/training_system/plan_document.rb test/test_helper.rb test/yaml_loader_test.rb test/plan_document_test.rb
git commit -m "test: add training data readers"
```

### Task 2: Canonical source-data contract

**Files:**
- Create: `data/profile.yaml`
- Modify: `data/equipment.yaml`
- Modify: `data/preferences.md`
- Create: `data/exercise_library.yaml`
- Create: `data/coaching_rules.md`
- Create: `data/history_summary.md`
- Modify: `calendar/exceptions.yaml`
- Create: `state/current.yaml`
- Create: `lib/training_system/repository_validator.rb`
- Create: `test/repository_validator_test.rb`

**Interfaces:**
- Consumes: canonical core files under `data/`, `calendar/`, and `state/`.
- Produces: `TrainingSystem::Diagnostic = Data.define(:severity, :code, :path, :message)`.
- Produces: `TrainingSystem::RepositoryValidator.new(root).call -> Array<Diagnostic>`.
- Later tasks extend the same validator with active-block checks.

- [ ] **Step 1: Write the failing required-file test**

Create `test/repository_validator_test.rb` with the initial case:

```ruby
# frozen_string_literal: true

require_relative "test_helper"
require "training_system/repository_validator"

class RepositoryValidatorTest < Minitest::Test
  include RepositoryFixture

  def test_reports_each_missing_core_file
    with_repository do |root|
      diagnostics = TrainingSystem::RepositoryValidator.new(root).call
      codes = diagnostics.map(&:code)

      assert_includes codes, "missing_profile"
      assert_includes codes, "missing_equipment"
      assert_includes codes, "missing_exercise_library"
      assert_includes codes, "missing_current_state"
    end
  end
end
```

- [ ] **Step 2: Run the test and verify the red state**

Run: `ruby -Itest test/repository_validator_test.rb`

Expected: FAIL with `cannot load such file -- training_system/repository_validator`.

- [ ] **Step 3: Implement the required-file validator**

Create `lib/training_system/repository_validator.rb`:

```ruby
# frozen_string_literal: true

require_relative "yaml_loader"

module TrainingSystem
  Diagnostic = Data.define(:severity, :code, :path, :message)

  class RepositoryValidator
    REQUIRED_FILES = {
      "data/profile.yaml" => "missing_profile",
      "data/equipment.yaml" => "missing_equipment",
      "data/preferences.md" => "missing_preferences",
      "data/exercise_library.yaml" => "missing_exercise_library",
      "data/coaching_rules.md" => "missing_coaching_rules",
      "data/history_summary.md" => "missing_history_summary",
      "calendar/exceptions.yaml" => "missing_calendar_exceptions",
      "state/current.yaml" => "missing_current_state"
    }.freeze

    def initialize(root)
      @root = root
    end

    def call
      REQUIRED_FILES.filter_map do |relative_path, code|
        next if File.file?(absolute(relative_path))

        Diagnostic.new(
          severity: "error",
          code: code,
          path: relative_path,
          message: "Required file is missing"
        )
      end
    end

    private

    def absolute(relative_path)
      File.join(@root, relative_path)
    end
  end
end
```

- [ ] **Step 4: Run the required-file test**

Run: `ruby -Itest test/repository_validator_test.rb`

Expected: 1 run, 0 failures, 0 errors.

- [ ] **Step 5: Create the canonical YAML source files**

Create `data/profile.yaml`:

```yaml
version: 1
goals:
  primary: strength_and_general_conditioning
  secondary: []
training:
  expected_strength_sessions_per_week: 3
  typical_session_minutes: 60
  default_session_sequence: [A, B, C]
  main_exercise_rotation_weeks: [8, 12]
cardio:
  optional_sessions_per_week: [0, 2]
  modalities: [running, outdoor_cycling, indoor_cycling]
logging:
  mode: structured_markdown
  required_fields: [working_sets, session_rpe, pain_or_limitations]
health:
  review_status: needs_user_review
  limitations: []
```

Replace `data/equipment.yaml` with an explicit unknown state instead of invented placeholder values:

```yaml
version: 1
review_status: needs_user_input
items: []
notes: "Doplnit před vygenerováním prvního bloku."
```

Create `data/exercise_library.yaml`:

```yaml
version: 1
exercises: []
```

Create `state/current.yaml`:

```yaml
version: 1
active_block: null
plan_status: none
sequence_position: null
next_session: null
```

Normalize `calendar/exceptions.yaml`:

```yaml
version: 1
exceptions: []
```

- [ ] **Step 6: Replace preference placeholders with confirmed decisions**

Rewrite `data/preferences.md` with these exact sections and confirmed content:

```markdown
# Preference

## Dlouhodobý směr

- Rozvoj síly a obecné kondice.
- Tři silové jednotky jako výchozí priorita.
- Přiměřená obměna, aby program neztratil zábavnost.

## Chci zkusit nebo častěji zařazovat

- Kalisteniku.
- Cviky na kruzích, pokud je vybavení dostupné.

## Míra obměny

- Hlavní varianty obvykle držet 8–12 týdnů, pokud fungují a nezpůsobují bolest nebo nudu.
- Doplňky lze obměňovat po jednotlivých blocích.

## Neověřené preference

- Frekvence cviku ve starých plánech neznamená, že byl oblíbený nebo skutečně odcvičený.

## Omezení a historie zranění

- Zatím nevyplněno. Před prvním blokem vyžaduje kontrolu uživatele.
```

- [ ] **Step 7: Create the durable coaching contract and empty history summary**

Create `data/coaching_rules.md` with these required sections:

```markdown
# Pravidla osobního trenéra

## Schvalování

- AI vytváří nejprve návrh se stavem `draft`.
- Aktivace a každá pozdější změna vyžaduje výslovné schválení uživatele.
- Schválený předpis se potichu nepřepisuje. Změna se přidá jako datovaný dodatek.

## Sekvence

- Výchozí sekvence je průběžná `A, B, C`, ale každý blok ji může zdůvodněně změnit.
- Zrušený termín neposouvá sekvenci.
- Dokončená jednotka sekvenci posune.
- Částečná jednotka vyžaduje rozhodnutí `repeat` nebo `advance`.

## Progrese a obměna

- Běžné silové cviky používají jako výchozí double progression podle rozsahu opakování a cílového RPE.
- Kalistenika a kruhy mohou postupovat variantou, rozsahem pohybu, kvalitou nebo menší dopomocí.
- Knihovna cviků není whitelist. Nový cvik musí být označený a zdůvodněný.
- Po schválení se nový cvik přidá do knihovny s `experience: planned`. Po prvním záznamu se zkušenost aktualizuje podle skutečnosti.
- Plán nepředepisuje konkrétní pracovní váhu.

## Kardio

- Volitelné kardio není povinnost a nevytváří náhradu.
- Integrovaná kondiční část prodlužuje jednotku a započítává se do zatížení nohou i okolních jednotek.
- Intenzivní cycling se bez výslovného zdůvodnění nekombinuje s vysokým objemem těžké silové práce pro nohy.
- Při prioritě síly probíhá silová část před kondiční.

## Bezpečnost

- Bolest má přednost před progresí a preferencemi.
- Při přetrvávajících nebo závažných potížích systém doporučí odborníka a nepředstírá diagnózu.

## Technické odkazy

- Známý cvik používá uložený ověřený odkaz.
- Neznámý cvik používá vyhledávací YouTube URL. AI nevymýšlí konkrétní video.
```

Create `data/history_summary.md`:

```markdown
# Potvrzené poznatky z nového systému

Zatím nejsou k dispozici dokončené bloky v novém formátu.
```

- [ ] **Step 8: Add schema-level validation tests**

Append these cases to `test/repository_validator_test.rb`:

```ruby
def test_rejects_invalid_default_sequence
  with_repository do |root|
    write_valid_core(root)
    profile = TrainingSystem::YamlLoader.load(File.join(root, "data/profile.yaml"))
    profile.fetch("training")["default_session_sequence"] = []
    File.write(File.join(root, "data/profile.yaml"), YAML.dump(profile))

    diagnostics = TrainingSystem::RepositoryValidator.new(root).call
    assert_includes diagnostics.map(&:code), "invalid_default_sequence"
  end
end

def test_equipment_may_be_explicitly_unreviewed
  with_repository do |root|
    write_valid_core(root)
    diagnostics = TrainingSystem::RepositoryValidator.new(root).call

    refute_includes diagnostics.map(&:code), "invalid_equipment"
    assert_includes diagnostics.map(&:code), "equipment_needs_input"
    assert_includes diagnostics.map(&:code), "health_needs_review"
  end
end
```

Also add a `write_valid_core(root)` helper to the test class that writes the exact canonical files from Steps 5–7. Do not use the real repository as a fixture.

```ruby
def write_valid_core(root)
  write(root, "data/profile.yaml", <<~YAML)
    version: 1
    goals:
      primary: strength_and_general_conditioning
      secondary: []
    training:
      expected_strength_sessions_per_week: 3
      typical_session_minutes: 60
      default_session_sequence: [A, B, C]
      main_exercise_rotation_weeks: [8, 12]
    cardio:
      optional_sessions_per_week: [0, 2]
      modalities: [running, outdoor_cycling, indoor_cycling]
    logging:
      mode: structured_markdown
      required_fields: [working_sets, session_rpe, pain_or_limitations]
    health:
      review_status: needs_user_review
      limitations: []
  YAML
  write(root, "data/equipment.yaml", <<~YAML)
    version: 1
    review_status: needs_user_input
    items: []
    notes: "Doplnit před vygenerováním prvního bloku."
  YAML
  write(root, "data/exercise_library.yaml", "version: 1\nexercises: []\n")
  write(root, "data/preferences.md", "# Preference\n")
  write(root, "data/coaching_rules.md", "# Pravidla osobního trenéra\n")
  write(root, "data/history_summary.md", "# Potvrzené poznatky z nového systému\n")
  write(root, "calendar/exceptions.yaml", "version: 1\nexceptions: []\n")
  write(root, "state/current.yaml", <<~YAML)
    version: 1
    active_block: null
    plan_status: none
    sequence_position: null
    next_session: null
  YAML
end
```

- [ ] **Step 9: Extend core-data validation**

Add to `RepositoryValidator#call` after the required-file checks:

```ruby
diagnostics = missing_file_diagnostics
return diagnostics if diagnostics.any? { |diagnostic| diagnostic.severity == "error" }

profile = YamlLoader.load(absolute("data/profile.yaml"))
equipment = YamlLoader.load(absolute("data/equipment.yaml"))

sequence = profile.dig("training", "default_session_sequence")
unless sequence.is_a?(Array) && sequence.any? && sequence.all? { |name| name.is_a?(String) && !name.empty? }
  diagnostics << Diagnostic.new(
    severity: "error",
    code: "invalid_default_sequence",
    path: "data/profile.yaml",
    message: "training.default_session_sequence must be a non-empty list of names"
  )
end

if equipment["review_status"] == "needs_user_input"
  diagnostics << Diagnostic.new(
    severity: "warning",
    code: "equipment_needs_input",
    path: "data/equipment.yaml",
    message: "Equipment must be reviewed before generating the first block"
  )
end

if profile.dig("health", "review_status") == "needs_user_review"
  diagnostics << Diagnostic.new(
    severity: "warning",
    code: "health_needs_review",
    path: "data/profile.yaml",
    message: "Health limitations must be reviewed before generating the first block"
  )
end

diagnostics
```

Refactor the initial body into a private `missing_file_diagnostics` method so `call` has one responsibility per stage.

- [ ] **Step 10: Run Task 2 tests**

Run: `ruby -Itest test/repository_validator_test.rb`

Expected: all tests pass; the canonical repository emits the intentional `equipment_needs_input` and `health_needs_review` warnings.

- [ ] **Step 11: Commit after the complete-diff approval gate**

Do not run this during normal implementation. After the user approves the complete implementation diff:

```bash
git add data/profile.yaml data/equipment.yaml data/preferences.md data/exercise_library.yaml data/coaching_rules.md data/history_summary.md calendar/exceptions.yaml state/current.yaml lib/training_system/repository_validator.rb test/repository_validator_test.rb
git commit -m "feat: define canonical training data"
```

### Task 3: Block templates and rolling sequence

**Files:**
- Create: `templates/plan.md`
- Create: `templates/session-log.md`
- Create: `templates/block-review.md`
- Create: `blocks/.gitkeep`
- Create: `lib/training_system/sequence.rb`
- Create: `test/sequence_test.rb`
- Modify: `test/plan_document_test.rb`

**Interfaces:**
- Consumes: an ordered list of template names and the last completed template.
- Produces: `TrainingSystem::Sequence.next(sequence:, position:) -> String`.
- Produces: `TrainingSystem::Sequence.after_incomplete(sequence:, current:, decision:) -> String` where decision is `"repeat"` or `"advance"`.
- Produces: Markdown templates matching `PlanDocument` and the approved spec.

- [ ] **Step 1: Write failing rolling-sequence tests**

Create `test/sequence_test.rb`:

```ruby
# frozen_string_literal: true

require_relative "test_helper"
require "training_system/sequence"

class SequenceTest < Minitest::Test
  def test_starts_with_first_template
    assert_equal "A", TrainingSystem::Sequence.next(sequence: %w[A B C], position: nil)
  end

  def test_continues_after_sequence_position
    assert_equal "C", TrainingSystem::Sequence.next(sequence: %w[A B C], position: "B")
    assert_equal "A", TrainingSystem::Sequence.next(sequence: %w[A B C], position: "C")
  end

  def test_canceled_date_does_not_change_next_template
    before_cancel = TrainingSystem::Sequence.next(sequence: %w[A B C], position: "B")
    after_cancel = TrainingSystem::Sequence.next(sequence: %w[A B C], position: "B")

    assert_equal "C", before_cancel
    assert_equal before_cancel, after_cancel
  end

  def test_partial_session_requires_explicit_decision
    assert_equal "C", TrainingSystem::Sequence.after_incomplete(
      sequence: %w[A B C], current: "C", decision: "repeat"
    )
    assert_equal "A", TrainingSystem::Sequence.after_incomplete(
      sequence: %w[A B C], current: "C", decision: "advance"
    )
    assert_raises(ArgumentError) do
      TrainingSystem::Sequence.after_incomplete(
        sequence: %w[A B C], current: "C", decision: nil
      )
    end
  end
end
```

- [ ] **Step 2: Run sequence tests and verify the red state**

Run: `ruby -Itest test/sequence_test.rb`

Expected: FAIL with `cannot load such file -- training_system/sequence`.

- [ ] **Step 3: Implement rolling-sequence logic**

Create `lib/training_system/sequence.rb`:

```ruby
# frozen_string_literal: true

module TrainingSystem
  module Sequence
    module_function

    def next(sequence:, position:)
      validate_sequence!(sequence)
      return sequence.first if position.nil?

      index = sequence.index(position)
      raise ArgumentError, "Unknown sequence position: #{position}" unless index

      sequence.fetch((index + 1) % sequence.length)
    end

    def after_incomplete(sequence:, current:, decision:)
      validate_sequence!(sequence)
      raise ArgumentError, "Unknown current template: #{current}" unless sequence.include?(current)

      case decision
      when "repeat"
        current
      when "advance"
        self.next(sequence: sequence, position: current)
      else
        raise ArgumentError, "Incomplete session decision must be repeat or advance"
      end
    end

    def validate_sequence!(sequence)
      return if sequence.is_a?(Array) && sequence.any? && sequence.uniq.length == sequence.length

      raise ArgumentError, "Sequence must contain unique template names"
    end
    private_class_method :validate_sequence!
  end
end
```

- [ ] **Step 4: Run sequence tests and verify the green state**

Run: `ruby -Itest test/sequence_test.rb`

Expected: 4 runs, 0 failures, 0 errors.

- [ ] **Step 5: Create the plan template**

Create `templates/plan.md` with null identity fields that prevent accidental activation:

```markdown
---
block: null
status: draft
planned_duration_weeks: 4
session_sequence: [A, B, C]
target_strength_sessions: 12
approved_on: null
---

# Záměr bloku

# Změny oproti minulému bloku

# Předpoklady ke kontrole

# Společná pravidla

## Trénink A

| Cvik | Série | Opakování | Cílové RPE | Pauza | Technika |
|------|-------|------------|------------|-------|----------|

## Trénink B

| Cvik | Série | Opakování | Cílové RPE | Pauza | Technika |
|------|-------|------------|------------|-------|----------|

## Trénink C

| Cvik | Série | Opakování | Cílové RPE | Pauza | Technika |
|------|-------|------------|------------|-------|----------|

# Progrese během bloku

# Volitelné kardio

# Schválené změny během bloku
```

- [ ] **Step 6: Create the session-log template**

Create `templates/session-log.md`:

```markdown
---
session: null
template: null
date: null
status: planned
duration_minutes: null
sequence_decision: null
---

# Záznam silové jednotky

## Výsledky

| Cvik | Série | Váha | Opakování | RPE |
|------|-------|------|------------|-----|

## Integrovaná kondiční část

- modalita:
- délka:
- intenzita:

## Krátké hodnocení

- celkové RPE:
- zábavnost:
- bolest nebo omezení:
- poznámka:
```

Allowed final `status` values are `completed`, `partial`, and `aborted`. When status is `partial` or `aborted`, `sequence_decision` must become `repeat` or `advance` before `state/current.yaml` changes.

- [ ] **Step 7: Create the block-review template**

Create `templates/block-review.md`:

```markdown
# Hodnocení bloku

## Souhrn

- plánovaný horizont:
- dokončené silové jednotky:
- částečné nebo ukončené jednotky:
- zaznamenané kardio:

## Progres hlavních cviků

## RPE a regenerace

## Bolest nebo omezení

## Zábavnost a obměna

## Doporučení pro další blok

- ponechat:
- obměnit:
- později vrátit:
- navrhované zaměření:
```

- [ ] **Step 8: Test that the plan template satisfies the parser contract**

Append to `test/plan_document_test.rb`:

```ruby
def test_repository_plan_template_has_required_sections
  path = File.expand_path("../templates/plan.md", __dir__)
  document = TrainingSystem::PlanDocument.new(path)
  required = [
    "Záměr bloku",
    "Společná pravidla",
    "Trénink A",
    "Trénink B",
    "Trénink C",
    "Progrese během bloku",
    "Volitelné kardio",
    "Schválené změny během bloku"
  ]

  assert_empty document.require_headings(*required)
  assert_equal "draft", document.metadata.fetch("status")
end
```

- [ ] **Step 9: Run Task 3 tests**

Run: `ruby -Itest -e 'Dir["test/{plan_document,sequence}_test.rb"].sort.each { |file| require File.expand_path(file) }'`

Expected: all tests pass.

- [ ] **Step 10: Commit after the complete-diff approval gate**

Do not run this during normal implementation. After the user approves the complete implementation diff:

```bash
git add templates/plan.md templates/session-log.md templates/block-review.md blocks/.gitkeep lib/training_system/sequence.rb test/sequence_test.rb test/plan_document_test.rb
git commit -m "feat: add block templates and sequence rules"
```

### Task 4: Active-block validation and CLI

**Files:**
- Modify: `lib/training_system/repository_validator.rb`
- Modify: `test/repository_validator_test.rb`
- Create: `bin/validate`

**Interfaces:**
- Consumes: `state/current.yaml`, the active block's `plan.md`, and files under `sessions/`.
- Produces: diagnostics with stable codes for scripts and human-readable messages for the user.
- Produces: `bin/validate [ROOT]`, with exit `0` when there are no errors and exit `1` when any error exists. Warnings do not change the exit code.

- [ ] **Step 1: Write failing active-block validation tests**

Append the following cases to `test/repository_validator_test.rb`. The helper `write_active_block(root, status:, duration:, sequence:, sequence_position:, next_session:)` must write valid core files, `state/current.yaml`, and `blocks/2026-09-block-001/plan.md` using the arguments.

Add the exact helper:

```ruby
def write_active_block(root, status:, duration:, sequence:, sequence_position:, next_session:)
  write_valid_core(root)
  write(root, "state/current.yaml", YAML.dump(
    "version" => 1,
    "active_block" => "2026-09-block-001",
    "plan_status" => status,
    "sequence_position" => sequence_position,
    "next_session" => next_session
  ))

  workout_sections = sequence.map { |name| "## Trénink #{name}\n" }.join("\n")
  write(root, "blocks/2026-09-block-001/plan.md", <<~MARKDOWN)
    ---
    block: 2026-09-block-001
    status: #{status}
    planned_duration_weeks: #{duration}
    session_sequence: #{sequence.inspect}
    target_strength_sessions: #{duration * 3}
    approved_on: 2026-09-01
    ---
    # Záměr bloku
    # Společná pravidla
    #{workout_sections}
    # Progrese během bloku
    # Volitelné kardio
    # Schválené změny během bloku
  MARKDOWN
end

def write_session(root, template:, status:, sequence_decision: nil)
  write(root, "blocks/2026-09-block-001/sessions/01-#{template}.md", <<~MARKDOWN)
    ---
    session: 1
    template: #{template}
    date: 2026-09-02
    status: #{status}
    duration_minutes: 45
    sequence_decision: #{sequence_decision.inspect}
    ---
    # Záznam silové jednotky
    ## Výsledky
    ## Krátké hodnocení
  MARKDOWN
end
```

```ruby
def test_draft_plan_cannot_be_active
  with_repository do |root|
    write_active_block(
      root,
      status: "draft",
      duration: 4,
      sequence: %w[A B C],
      sequence_position: nil,
      next_session: "A"
    )

    diagnostics = TrainingSystem::RepositoryValidator.new(root).call
    assert_includes diagnostics.map(&:code), "draft_plan_is_active"
  end
end

def test_duration_must_be_between_three_and_six_weeks
  with_repository do |root|
    write_active_block(
      root,
      status: "approved",
      duration: 7,
      sequence: %w[A B C],
      sequence_position: nil,
      next_session: "A"
    )

    diagnostics = TrainingSystem::RepositoryValidator.new(root).call
    assert_includes diagnostics.map(&:code), "invalid_block_duration"
  end
end

def test_next_session_must_follow_sequence_position
  with_repository do |root|
    write_active_block(
      root,
      status: "approved",
      duration: 4,
      sequence: %w[A B C],
      sequence_position: "B",
      next_session: "A"
    )

    diagnostics = TrainingSystem::RepositoryValidator.new(root).call
    assert_includes diagnostics.map(&:code), "invalid_next_session"
  end
end

def test_valid_active_block_has_no_errors
  with_repository do |root|
    write_active_block(
      root,
      status: "approved",
      duration: 5,
      sequence: %w[A B C],
      sequence_position: "B",
      next_session: "C"
    )

    diagnostics = TrainingSystem::RepositoryValidator.new(root).call
    assert_empty diagnostics.select { |diagnostic| diagnostic.severity == "error" }
  end
end

def test_incomplete_session_requires_sequence_decision
  with_repository do |root|
    write_active_block(
      root,
      status: "approved",
      duration: 4,
      sequence: %w[A B C],
      sequence_position: nil,
      next_session: "A"
    )
    write_session(root, template: "A", status: "partial")

    diagnostics = TrainingSystem::RepositoryValidator.new(root).call
    assert_includes diagnostics.map(&:code), "missing_sequence_decision"
  end
end

def test_session_template_must_belong_to_plan_sequence
  with_repository do |root|
    write_active_block(
      root,
      status: "approved",
      duration: 4,
      sequence: %w[A B C],
      sequence_position: nil,
      next_session: "A"
    )
    write_session(root, template: "D", status: "completed")

    diagnostics = TrainingSystem::RepositoryValidator.new(root).call
    assert_includes diagnostics.map(&:code), "unknown_session_template"
  end
end
```

- [ ] **Step 2: Run validator tests and verify the red state**

Run: `ruby -Itest test/repository_validator_test.rb`

Expected: FAIL because active-block invariants are not implemented.

- [ ] **Step 3: Implement active-block validation**

Require `plan_document` and `sequence` at the top of `repository_validator.rb`. Add this call after core validation:

```ruby
validate_active_block(diagnostics)
```

Add private methods with the following behavior:

```ruby
def validate_active_block(diagnostics)
  current = YamlLoader.load(absolute("state/current.yaml"))
  active_block = current["active_block"]
  return if active_block.nil?

  relative_plan = File.join("blocks", active_block, "plan.md")
  plan_path = absolute(relative_plan)
  unless File.file?(plan_path)
    diagnostics << diagnostic("error", "missing_active_plan", relative_plan, "Active block plan is missing")
    return
  end

  plan = PlanDocument.new(plan_path)
  metadata = plan.metadata
  diagnostics << diagnostic("error", "draft_plan_is_active", relative_plan, "Draft plan cannot be active") if metadata["status"] != "approved"

  duration = metadata["planned_duration_weeks"]
  unless duration.is_a?(Integer) && (3..6).cover?(duration)
    diagnostics << diagnostic("error", "invalid_block_duration", relative_plan, "planned_duration_weeks must be between 3 and 6")
  end

  sequence = metadata["session_sequence"]
  expected_next = Sequence.next(sequence: sequence, position: current["sequence_position"])
  if current["next_session"] != expected_next
    diagnostics << diagnostic("error", "invalid_next_session", "state/current.yaml", "next_session must be #{expected_next}")
  end

  required_headings = [
    "Záměr bloku",
    "Společná pravidla",
    "Progrese během bloku",
    "Volitelné kardio",
    "Schválené změny během bloku"
  ] + sequence.map { |name| "Trénink #{name}" }
  missing_headings = plan.require_headings(*required_headings)
  missing_headings.each do |heading|
    diagnostics << diagnostic("error", "missing_plan_heading", relative_plan, "Missing heading: #{heading}")
  end
  validate_session_logs(diagnostics, active_block, sequence)
rescue DataError, ArgumentError => error
  diagnostics << diagnostic("error", "invalid_active_block", "state/current.yaml", error.message)
end

def validate_session_logs(diagnostics, active_block, sequence)
  pattern = absolute(File.join("blocks", active_block, "sessions", "*.md"))
  Dir.glob(pattern).sort.each do |path|
    relative_path = path.delete_prefix("#{@root}/")
    filename = File.basename(path)
    unless filename.match?(/\A\d{2}-.+\.md\z/)
      diagnostics << diagnostic("error", "invalid_session_filename", relative_path, "Use NN-TEMPLATE.md")
      next
    end

    metadata = PlanDocument.new(path).metadata
    template = metadata["template"]
    status = metadata["status"]
    unless sequence.include?(template)
      diagnostics << diagnostic("error", "unknown_session_template", relative_path, "Template is not in the plan sequence")
    end
    unless %w[completed partial aborted].include?(status)
      diagnostics << diagnostic("error", "invalid_session_status", relative_path, "Status must be completed, partial, or aborted")
    end
    if %w[partial aborted].include?(status) && !%w[repeat advance].include?(metadata["sequence_decision"])
      diagnostics << diagnostic("error", "missing_sequence_decision", relative_path, "Incomplete session requires repeat or advance")
    end
  rescue DataError => error
    diagnostics << diagnostic("error", "invalid_session_log", relative_path, error.message)
  end
end

def diagnostic(severity, code, path, message)
  Diagnostic.new(severity: severity, code: code, path: path, message: message)
end
```

- [ ] **Step 4: Run active-block tests and verify the green state**

Run: `ruby -Itest test/repository_validator_test.rb`

Expected: all tests pass.

- [ ] **Step 5: Write a failing CLI smoke test**

Append to `test/repository_validator_test.rb`:

```ruby
def test_cli_exits_nonzero_for_invalid_repository
  with_repository do |root|
    command = [RbConfig.ruby, File.expand_path("../bin/validate", __dir__), root]
    _output, status = Open3.capture2e(*command)

    refute status.success?
  end
end
```

Add `require "open3"` and `require "rbconfig"` at the top of the test file.

- [ ] **Step 6: Run the CLI test and verify the red state**

Run: `ruby -Itest test/repository_validator_test.rb -n test_cli_exits_nonzero_for_invalid_repository`

Expected: FAIL because `bin/validate` does not exist.

- [ ] **Step 7: Implement the CLI**

Create executable `bin/validate`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "training_system/repository_validator"

root = File.expand_path(ARGV.shift || ".")
diagnostics = TrainingSystem::RepositoryValidator.new(root).call

diagnostics.each do |diagnostic|
  puts "#{diagnostic.severity.upcase} #{diagnostic.code} #{diagnostic.path}: #{diagnostic.message}"
end

errors = diagnostics.count { |diagnostic| diagnostic.severity == "error" }
warnings = diagnostics.count { |diagnostic| diagnostic.severity == "warning" }
puts "Validation complete: #{errors} error(s), #{warnings} warning(s)"

exit(errors.zero? ? 0 : 1)
```

Run: `chmod +x bin/validate`

- [ ] **Step 8: Run all automated tests and the real-repository validator**

Run: `ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |file| require File.expand_path(file) }'`

Expected: all tests pass.

Run: `bin/validate`

Expected before equipment and health onboarding: exit `0`, summary `0 error(s), 2 warning(s)`, warning codes `equipment_needs_input` and `health_needs_review`.

- [ ] **Step 9: Commit after the complete-diff approval gate**

Do not run this during normal implementation. After the user approves the complete implementation diff:

```bash
git add bin/validate lib/training_system/repository_validator.rb test/repository_validator_test.rb
git commit -m "feat: validate active training blocks"
```

### Task 5: Workflow instructions, archive migration, and acceptance verification

**Files:**
- Modify: `AGENTS.md`
- Preserve: `CLAUDE.md`
- Modify: `README.md`
- Modify: `ONBOARDING.md`
- Create: `archive/former-coach/raw/README.md`
- Create: `archive/former-coach/summary.md`
- Delete after migration: `data/coach_summary.md`
- Delete after migration: `data/exercise_library.md`
- Delete after migration: `history/_TEMPLATE.md`
- Delete after migration: `history/blocks_archive.md`
- Delete after migration: `history/coach_archive/README.md`
- Delete after migration: `plans/.gitkeep`
- Delete after migration: `state/periodization.yaml`
- Remove empty obsolete directories: `history/`, `plans/`

**Interfaces:**
- Consumes: the approved design, canonical data contract, templates, and validator from Tasks 1–4.
- Produces: an AI-operable repository with one documented generation path and one onboarding path.
- Produces: a migration where no non-placeholder former-coach content is lost.

- [ ] **Step 1: Inventory old content before removing any path**

Run:

```bash
find data history plans state -maxdepth 3 -type f -print | sort
```

Expected in the current repository: only placeholder data, templates, `.gitkeep`, and the former-coach archive README. If any real export appears under `history/coach_archive/`, stop deletion and move each file to `archive/former-coach/raw/` first.

- [ ] **Step 2: Create the former-coach archive contract**

Create `archive/former-coach/raw/README.md`:

```markdown
# Surové plány bývalého trenéra

Do této složky patří původní exporty a dokumenty beze změn. Nejsou důkazem skutečně odcvičených tréninků, použitých vah, progrese ani oblíbenosti cviků.

Běžné generování nového bloku tuto složku nečte. Používá pouze ověřené závěry z `../summary.md` a `../../../data/history_summary.md`.
```

Create `archive/former-coach/summary.md`:

```markdown
# Souhrn plánů bývalého trenéra

## Potvrzené skutečnosti

Zatím nebyl proveden import původních plánů.

## Hypotézy k ověření

Zatím žádné.
```

- [ ] **Step 3: Rewrite `ONBOARDING.md` around prescribed-plan evidence**

The document must instruct the agent to:

```markdown
1. Read every file under `archive/former-coach/raw/` without modifying it.
2. Extract exercise names, movement patterns, required equipment, and recurring programming styles.
3. Add exercises to `data/exercise_library.yaml` with `source: former_coach` and `experience: unknown`.
4. Put objective injuries or contraindications into a proposed profile change for user approval.
5. Put inferred likes or dislikes only under `Hypotézy k ověření`; prescription frequency is not preference.
6. Never infer completed sets, actual loads, RPE, adherence, or progress from a prescribed plan.
7. Present the proposed summary and data diff for user review before committing any import.
```

Include an example imported exercise using `experience: unknown` and a YouTube search URL rather than an invented direct video.

- [ ] **Step 4: Rewrite `AGENTS.md` as the authoritative operating contract**

Use these top-level sections in this order:

```markdown
# Osobní tréninkový systém

## Povinné zdroje před návrhem bloku
## Pořadí rozhodování
## Návrh a schválení bloku
## Struktura a délka bloku
## Progrese a rotace cviků
## Volitelné a integrované kardio
## Zápis skutečné jednotky
## Posun průběžné sekvence
## Hodnocení bloku
## Nové cviky a technické odkazy
## Bezpečnost a neúplná data
## Validace
```

Under required sources, load exactly:

```markdown
- `data/profile.yaml`
- `data/equipment.yaml`
- `data/preferences.md`
- `data/exercise_library.yaml`
- `data/coaching_rules.md`
- `data/history_summary.md`
- `calendar/exceptions.yaml`
- `state/current.yaml`
- aktivní nebo poslední `blocks/*/plan.md`
- aktivní nebo poslední `blocks/*/review.md`, pokud existuje
- posledních 4–6 záznamů z `blocks/*/sessions/`
- `archive/former-coach/summary.md` pouze jako inspiraci
```

The operating contract must state every Global Constraint from this plan. It must also require `bin/validate` before presenting a plan for approval and after updating `state/current.yaml`.

Under new exercises, require the `experience: planned` transition on plan approval and an experience update after the first actual log. Under block review, require confirmed reusable insights to be copied into `data/history_summary.md`; do not copy one-off impressions.

- [ ] **Step 5: Rewrite `README.md` for the user workflow**

Document these exact actions:

1. Fill `data/equipment.yaml` and review the health section of `data/profile.yaml`.
2. Optionally place old prescribed plans under `archive/former-coach/raw/` and run the onboarding workflow.
3. Ask AI for a new block with a short natural-language brief.
4. Review `blocks/<block-id>/plan.md` while it is `draft`.
5. Explicitly approve the plan before it becomes active.
6. Create `sessions/01-A.md`, `02-B.md`, `03-C.md`, and onward only as sessions are attempted.
7. After the review horizon, review `review.md` before requesting the next block.

Include the canonical repository tree and the command `bin/validate`.

- [ ] **Step 6: Migrate and remove obsolete placeholders**

Before deleting, copy any non-placeholder information into its canonical destination:

| Old path | Canonical destination |
|---|---|
| `data/coach_summary.md` | `archive/former-coach/summary.md` or `data/history_summary.md` |
| `data/exercise_library.md` | `data/exercise_library.yaml` |
| `history/_TEMPLATE.md` | `templates/session-log.md` |
| `history/blocks_archive.md` | `archive/former-coach/summary.md` |
| `history/coach_archive/*` | `archive/former-coach/raw/` |
| `state/periodization.yaml` | `data/coaching_rules.md`, `data/profile.yaml`, and `state/current.yaml` |

Use `apply_patch` for file deletion after confirming each source contains only migrated or placeholder content. Remove empty `history/` and `plans/` directories only after their files are gone.

- [ ] **Step 7: Verify the Claude import remains intact**

Run: `sed -n '1,20p' CLAUDE.md`

Expected exact content: `@AGENTS.md` followed by a newline.

- [ ] **Step 8: Run automated and document-level acceptance checks**

Run all tests:

```bash
ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |file| require File.expand_path(file) }'
```

Expected: all tests pass.

Run repository validation:

```bash
bin/validate
```

Expected before user equipment and health onboarding: `0 error(s), 2 warning(s)` with `equipment_needs_input` and `health_needs_review`.

Run stale-path and placeholder scans:

```bash
rg -n "state/periodization|history/_TEMPLATE|plans/YYYY" AGENTS.md README.md ONBOARDING.md data calendar state templates archive || true
```

Expected: no matches.

Run video-policy scan:

```bash
rg -n "youtube\.com/watch\?v=" data templates AGENTS.md || true
```

Expected: no matches until the user explicitly stores a verified video in `data/exercise_library.yaml`.

- [ ] **Step 9: Review the complete implementation diff with the user**

Run:

```bash
git add -N AGENTS.md CLAUDE.md README.md ONBOARDING.md data calendar state blocks templates archive bin lib test docs/superpowers/plans docs/superpowers/specs/2026-08-30-personal-training-system-design.md
git status --short
git diff -- AGENTS.md CLAUDE.md README.md ONBOARDING.md data calendar state blocks templates archive bin lib test docs/superpowers/plans docs/superpowers/specs/2026-08-30-personal-training-system-design.md
```

`git add -N` records intent-to-add only, so untracked file contents appear in the diff without staging those contents. Present the complete diff, validation output, and test output. Do not commit. Wait for the user's explicit approval.

- [ ] **Step 10: Commit only after explicit complete-diff approval**

After the user explicitly approves committing the complete implementation:

```bash
git add AGENTS.md CLAUDE.md README.md ONBOARDING.md data calendar state blocks templates archive bin lib test docs/superpowers/plans docs/superpowers/specs/2026-08-30-personal-training-system-design.md
git commit -m "feat: implement personal training system"
```

Do not add `.DS_Store`. Confirm `git status --short` after committing and report any remaining user-owned files.
