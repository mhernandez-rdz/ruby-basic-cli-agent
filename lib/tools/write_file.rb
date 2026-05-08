# frozen_string_literal: true

class WriteFile < Tool # :nodoc:
  def call(args)
    File.write(args['path'], args['content'])
  end

  class << self
    def tool_name
      "write_file"
    end

    def schema
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Writes content in a given file',
          parameters: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'File path' },
              content: { type: 'string', description: 'File content' }
            },
            required: ['path', 'content']
          }
        }
      }
    end
  end
end
