# frozen_string_literal: true

require_relative "test_helper"
require "training_system/yaml_loader"

class YamlLoaderTest < Minitest::Test
  def with_yaml(contents)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "source.yaml")
      File.write(path, contents)
      yield path
    end
  end

  def test_loads_a_hash_with_dates
    with_yaml("start_date: 2026-08-31\nitems:\n  - squat\n") do |path|
      assert_equal({ "start_date" => Date.new(2026, 8, 31), "items" => ["squat"] },
                   TrainingSystem::YamlLoader.load(path))
    end
  end

  def test_rejects_aliases_with_source_path
    with_yaml("defaults: &defaults\n  sets: 3\nsquat: *defaults\n") do |path|
      error = assert_raises(TrainingSystem::DataError) { TrainingSystem::YamlLoader.load(path) }

      assert_includes error.message, path
    end
  end

  def test_rejects_symbols_with_source_path
    with_yaml("value: :unsafe\n") do |path|
      error = assert_raises(TrainingSystem::DataError) { TrainingSystem::YamlLoader.load(path) }

      assert_includes error.message, path
    end
  end

  def test_coaching_rules_allow_unknown_exercises_without_invented_video_urls
    rules = File.read(File.expand_path("../data/coaching_rules.md", __dir__))

    assert_includes rules, "`exercise_library.yaml` není whitelist"
    assert_includes rules, "Neznámý cvik lze navrhnout"
    assert_includes rules, "YouTube search URL"
    assert_includes rules, "nikdy nevymýšlej konkrétní `watch?v=` odkaz"
  end
end
