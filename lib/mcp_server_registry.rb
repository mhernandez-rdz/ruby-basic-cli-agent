# frozen_string_literal: true

require_relative 'mcp_client'

class McpServerRegistry # :nodoc:
  def initialize(config)
    @clients = {}
    (config['mcp_servers'] || []).each do |server|
      client = McpClient.build(server)
      @clients[server['name']] = client
      register_tools(server['name'], client)
    end
  end

  def close_all
    @clients.each_value(&:close)
  end

  private

  def register_tools(server_name, client) # rubocop:disable Metrics/MethodLength
    client.list_tools.each do |tool| 
      name = "#{server_name}__#{tool['name']}"
      schema = tool['inputSchema']

      Class.new(Tool) do
        define_singleton_method(:tool_name) { name }
        define_singleton_method(:schema) do
          {
            type: 'function',
            function: {
              name: name,
              description: tool['description'] || "#{server_name}: #{tool['name']}",
              parameters: schema
            }
          }
        end
        define_method(:call) { |args| client.call_tool(tool['name'], args) }
      end
    end
  end
end
