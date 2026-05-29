# frozen_string_literal: true

require_relative 'mcp_client/stdio'
require_relative 'mcp_client/http'

module McpClient # :nodoc:
  class << self
    def build(config)
      case config['transport']
      when 'http'
        McpClient::Http.new(config['name'], config['url'], auth_token: config['auth_token'])
      else
        McpClient::Stdio.new(config['name'], config['command'], args: config['args'] || [])
      end
    end
  end
end
