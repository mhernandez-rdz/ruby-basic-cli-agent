# frozen_string_literal: true

class Tool # :nodoc:
  class << self
    def inherited(subclass)
      registry << subclass
    end

    def registry
      @registry ||= []
    end

    def find(name)
      registry.find { |t| t.tool_name == name }
    end

    def schemas
      registry.map(&:schema)
    end
  end
end
