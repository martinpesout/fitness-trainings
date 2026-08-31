# frozen_string_literal: true

require "date"
require "yaml"

module TrainingSystem
  class DataError < StandardError; end

  class YamlLoader
    def self.load(path)
      parse(File.read(path), path)
    rescue DataError
      raise
    rescue SystemCallError, Psych::Exception, ArgumentError => error
      raise DataError, "Cannot read YAML source #{path}: #{error.message}"
    end

    def self.parse(contents, path)
      value = YAML.safe_load(
        contents,
        permitted_classes: [Date],
        permitted_symbols: [],
        aliases: false
      )

      return value if value.is_a?(Hash) || value.is_a?(Array)

      raise DataError, "YAML source #{path} must contain a mapping or list"
    rescue Psych::Exception, ArgumentError => error
      raise DataError, "Invalid YAML source #{path}: #{error.message}"
    end
  end
end
