# frozen_string_literal: true

class ToolExecutor
  def call(tool_calls)
    tool_calls.map do |tool_call|
      tool_name = tool_call.dig('function', 'name')

      begin 
        args = JSON.parse(tool_call.dig('function', 'arguments'))
        puts "\n[tool: #{tool_name} #{args}]"
        tool = Tool.find(tool_name)
        result = tool ? tool.new.call(args) : "Tool error: unknown tool '#{tool_name}'"
      rescue JSON::ParserError => e
        result = "Error: Invalid arguments JSON: #{e.message}"
      rescue => e
        result = "Tool error: #{e.message}"
      end

      { role: 'tool', tool_call_id: tool_call['id'], content: result.to_s }
    end
  end
end
