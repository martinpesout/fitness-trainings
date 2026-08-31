# frozen_string_literal: true

module TrainingSystem
  class Sequence
    OUTCOMES = %w[completed partial aborted].freeze
    DECISIONS = %w[repeat advance].freeze

    def self.next(sequence:, position:, outcome: "completed", decision: nil)
      validate_sequence!(sequence)
      validate_position!(position, sequence)
      validate_outcome!(outcome, decision)

      return sequence.first if position.nil?
      return position if %w[partial aborted].include?(outcome) && decision == "repeat"

      sequence[(sequence.index(position) + 1) % sequence.length]
    end

    def self.validate_sequence!(sequence)
      unless sequence.is_a?(Array) && sequence.all? { |name| name.is_a?(String) && !name.strip.empty? } && sequence.uniq.length == sequence.length
        raise ArgumentError, "sequence must contain unique, non-empty string names"
      end

      raise ArgumentError, "sequence must not be empty" if sequence.empty?
    end
    private_class_method :validate_sequence!

    def self.validate_position!(position, sequence)
      return if position.nil?

      unless position.is_a?(String) && sequence.include?(position)
        raise ArgumentError, "position must be a sequence name or nil"
      end
    end
    private_class_method :validate_position!

    def self.validate_outcome!(outcome, decision)
      raise ArgumentError, "outcome must be completed, partial, or aborted" unless OUTCOMES.include?(outcome)
      return if outcome == "completed" && decision.nil?
      return if %w[partial aborted].include?(outcome) && DECISIONS.include?(decision)

      raise ArgumentError, "partial and aborted outcomes require decision repeat or advance"
    end
    private_class_method :validate_outcome!
  end
end
