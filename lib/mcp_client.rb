# frozen_string_literal: true

class McpClient # :nodoc:
  def initialize(name, command, args: [], env: {})
    @name = name
    @seq = 0
    @stdin, @stdout, @thread = Open3.popen2(env, command, *args)
    handshake
  end

  def list_tools
    response = send_request('tools/list')
    response.dig('result', 'tools') || []
  end

  def call_tool(name, arguments)
    response = send_request('tools/call', { name: name, arguments: arguments })
    response.dig('result', 'content')&.map { |c| c['text'] }&.join("\n") || ''
  end

  def close
    @stdin.close
    @thread.join
  end

  private

  def handshake
    send_request('initialize',
                 { protocolVersion: '2024-11-05',
                   capabilities: {},
                   clientInfo: { name: 'llm-harness', version: '1.0' } })
    send_notification('notifications/initialized')
  end

  def send_request(method, params = {})
    @seq += 1
    write({ jsonrpc: '2.0', id: @seq, method: method, params: params })
    loop do
      msg = read
      return msg if msg['id'] == @seq
    end
  end

  def send_notification(method, params = {})
    write({ jsonrpc: '2.0', method: method, params: params })
  end

  def write(payload)
    @stdin.puts(JSON.generate(payload))
    @stdin.flush
  end

  def read
    JSON.parse(@stdout.readline)
  end
end
