# frozen_string_literal: true

class ReadFile < Tool # :nodoc:
  def call(args)
    File.read(args['path'])
  end

  class << self
    def tool_name
      "read_file"
    end

    def schema
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Reads the content of a given file',
          parameters: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'File path' }
            },
            required: ['path']
          }
        }
      }
    end
  end
end
