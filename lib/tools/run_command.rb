# frozen_string_literal: true

require 'open3'
require 'shellwords'

class RunCommand < Tool # :nodoc:
  def call(args)
    stdout, stderr, _status = Open3.capture3(*Shellwords.split(args['command']))
    stdout.empty? ? stderr : stdout
  end

  class << self
    def tool_name
      "run_command"
    end

    def schema
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Run system commands',
          parameters: {
            type: 'object',
            properties: {
              command: { type: 'string', description: 'Command to run' },
            },
            required: ['command']
          }
        }
      }
    end
  end
end
