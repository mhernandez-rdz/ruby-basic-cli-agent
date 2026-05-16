# frozen_string_literal: true

class ListDir < Tool # :nodoc:
  SKIP_ENTRIES = ['.', '..'].freeze

  def call(args)
    Dir.entries(args['path']).reject { |e| SKIP_ENTRIES.include?(e) }.join("\n")
  end

  class << self
    def tool_name
      'list_dir'
    end

    def schema
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Lists the content of a given directory',
          parameters: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'Directory path' }
            },
            required: ['path']
          }
        }
      }
    end
  end
end
