# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module McpClient
  class Http # :nodoc:
    def initialize(name, url, auth_token: nil)
      @name = name
      @url = url
      @auth_token = auth_token
      @seq = 0
      @queue = Queue.new
      @endpoint_queue = Queue.new
      start_sse_listener
      @message_endpoint = @endpoint_queue.pop
      raise 'MCP HTTP connection failed' if @message_endpoint.nil?

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
      @sse_thread.kill
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
      uri = URI("#{@url}#{@message_endpoint}")
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: nil) do |http|
        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req['Authorization'] = "Bearer #{@auth_token}" if @auth_token
        req.body = JSON.generate(payload)
        http.request(req)
      end
    end

    def read
      @queue.pop
    end

    def start_sse_listener # rubocop:disable Metrics/MethodLength
      uri = URI("#{@url}/sse")
      @sse_thread = Thread.new do
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: nil) do |http|
          req = Net::HTTP::Get.new(uri)
          req['Accept'] = 'text/event-stream'
          req['Cache-Control'] = 'no-cache'
          req['Accept-Encoding'] = 'identity'
          req['Authorization'] = "Bearer #{@auth_token}" if @auth_token
          http.request(req) do |response|
            buffer = ''
            response.read_body do |chunk|
              buffer += chunk
              while (pos = buffer.index("\n\n"))
                parse_sse_event(buffer[0...pos])
                buffer = buffer[(pos + 2)..]
              end
            end
          end
        end
      rescue StandardError
        @endpoint_queue << nil
      end
    end

    def parse_sse_event(raw)
      event_type = nil
      data = nil
      raw.each_line do |line|
        event_type = line[7..].chomp if line.start_with?('event: ')
        data       = line[6..].chomp if line.start_with?('data: ')
      end
      case event_type
      when 'endpoint' then @endpoint_queue << data
      when 'message'  then @queue << JSON.parse(data)
      end
    end
  end
end
