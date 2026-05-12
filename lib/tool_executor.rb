# frozen_string_literal: true

require_relative 'permissions'
require_relative 'path_guard'

class ToolExecutor # :nodoc:
  def initialize
    @permissions = Permissions.new
    @path_guard = PathGuard.new
  end

  def call(tool_calls)
    tool_calls.map do |tool_call|
      tool_name = tool_call.dig('function', 'name')

      begin 
        args = JSON.parse(tool_call.dig('function', 'arguments'))
        puts "\n[tool: #{tool_name} #{args}]"
        result = handle_tool(tool_name:, args:)
      rescue JSON::ParserError => e
        result = "Error: Invalid arguments JSON: #{e.message}"
      rescue => e
        result = "Tool error: #{e.message}"
      end

      { role: 'tool', tool_call_id: tool_call['id'], content: result.to_s }
    end
  end

  private

  def handle_tool(tool_name:, args:)
    tool = Tool.find(tool_name)
    return "Tool error: unknown tool '#{tool_name}'" unless tool

    if tool_name == 'run_command'
      unless @permissions.allowed?(args['command'])
        print "\n[permission required] run '#{args['command']}'? [y/N]: "
        return "Error: permission denied" unless gets&.chomp&.downcase == 'y'
      end
    elsif args['path'] && !@path_guard.safe?(args['path'])
      return "Error path '#{args['path']}' is outside allowed directories"
    end

    tool.new.call(args)
  end
end
