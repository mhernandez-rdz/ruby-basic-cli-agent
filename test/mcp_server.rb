#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

def respond(id, result)
  $stdout.puts JSON.generate({ jsonrpc: '2.0', id:, result: })
  $stdout.flush
end

$stdin.each_line do |line|
  msg = JSON.parse(line)
  case msg['method']
  when 'initialize'
    respond(msg['id'], {
              protocolVersion: '2024-11-05',
              capabilities: { tools: {} },
              serverInfo: { name: 'test-server', version: '1.0' }
            })
  when 'notifications/initialized'
    # no response
  when 'tools/list'
    respond(msg['id'], { tools: [
              {
                name: 'echo',
                description: 'Echoes the input back',
                inputSchema: {
                  type: 'object',
                  properties: { message: { type: 'string' } },
                  required: ['message']
                }
              },
              {
                name: 'reverse',
                description: 'Reverses a string',
                inputSchema: {
                  type: 'object',
                  properties: { text: { type: 'string' } },
                  required: ['text']
                }
              }
            ] })
  when 'tools/call'
    name = msg.dig('params', 'name')
    args = msg.dig('params', 'arguments')
    result = case name
             when 'echo'    then args['message']
             when 'reverse' then args['text'].reverse
             else "unknown tool: #{name}"
             end
    respond(msg['id'], { content: [{ type: 'text', text: result }] })
  end
end
