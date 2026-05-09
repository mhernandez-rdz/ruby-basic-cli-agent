# frozen_string_literal: true

class EditFile < Tool # :nodoc:
  def call(args)
    content = File.read(args['path'])
    raise "old_str not found in file" unless content.include?(args['old_str'])

    updated = content.sub(args['old_str'], args['new_str'])
    File.write(args['path'], updated)
    "OK"
  end

  class << self
    def tool_name
      "edit_file"
    end

    def schema
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Edits content of a given file',
          parameters: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'File path' },
              old_str: { type: 'string', description: 'Text to replace' },
              new_str: { type: 'string', description: 'New text' }
            },
            required: ['path', 'old_str', 'new_str']
          }
        }
      }
    end
  end
end
