# frozen_string_literal: true

require "training_system/yaml_loader"

module TrainingSystem
  class PlanDocument
    attr_reader :metadata, :headings

    def initialize(path)
      @path = path
      contents = File.read(path)
      front_matter = contents.match(/\A---[ \t]*\r?\n(?<yaml>.*?)\r?\n---[ \t]*(?:\r?\n|\z)/m)
      raise DataError, "Plan document #{@path} is missing YAML front matter" unless front_matter

      @metadata = YamlLoader.parse(front_matter[:yaml], @path)
      unless @metadata.is_a?(Hash)
        raise DataError, "Plan document #{@path} front matter must be a mapping"
      end

      body = contents[front_matter.end(0)..]
      @headings = body.scan(/^\#{1,6}[ \t]+(.+?)(?:[ \t]+\#+)?[ \t]*$/).flatten.map(&:strip)
    rescue DataError
      raise
    rescue SystemCallError => error
      raise DataError, "Cannot read plan document #{@path}: #{error.message}"
    end

    def require_headings(names)
      names.reject { |name| headings.include?(name) }
    end
  end
end
