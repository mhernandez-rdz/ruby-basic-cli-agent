# frozen_string_literal: true

require_relative 'utils/config'

class Client # :nodoc:
  def initialize
    @config = Config.read_config
    raise "Run 'bin/run --setup' first" unless @config['base_url'] && @config['model']

    @api_key = ENV['OPENCODE_API_KEY']
    @uri = URI("#{@config['base_url']}/chat/completions")
  end

  def chat(messages, tools: [])
    raw_chat(messages, tools:)&.dig('content')
  end

  def raw_chat(messages, tools: [])
    request = build_request(messages, tools:)
    response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http| 
      http.request(request)
    end
    body = JSON.parse(response.body)
    body.dig("choices", 0, "message") or raise "Unexpected API response: #{body}"
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise 'API timeout - check your connection...'
  rescue Errno::ECONNREFUSED
    raise 'Could not connect to API'
  end

  def stream_chat(messages, tools: [], &on_content)
    assembled = { 'role' => 'assistant', 'content' => '' }
    buffer = ''

    Net::HTTP.start(@uri.host, @uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      http.request(build_request(messages, tools: tools, stream: true)) do |response|
        response.read_body do |chunk|
          buffer += chunk
          while (newline = buffer.index("\n"))
            line = buffer.slice!(0, newline + 1).chomp
            next unless line.start_with?('data: ')
            data = line.delete_prefix('data: ')
            next if data.strip == '[DONE]'

            delta = JSON.parse(data).dig('choices', 0, 'delta') || {}

            if delta['content']
              on_content.call(delta['content'])
              assembled['content'] += delta['content']
            end

            if delta['reasoning_content']
              assembled['reasoning_content'] ||= ''
              assembled['reasoning_content'] += delta['reasoning_content']
            end

            next unless delta['tool_calls']

            assembled['tool_calls'] ||= []
            delta['tool_calls'].each do |tc|
              idx = tc['index']
              assembled['tool_calls'][idx] ||= { 'id' => '', 'type' => 'function',
                                                 'function' => { 'name' => '', 'arguments' => '' } }
              t = assembled['tool_calls'][idx]
              t['id']                    += tc['id']                        || ''
              t['function']['name']      += tc.dig('function', 'name')      || ''
              t['function']['arguments'] += tc.dig('function', 'arguments') || ''
            end
          end
        end
      end
    end
    assembled['content'] = nil if assembled['tool_calls']&.any?
    assembled
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise 'API timeout - check your connection...'
  rescue Errno::ECONNREFUSED
    raise 'Could not connect to API'
  end

  private

  def build_request(messages, tools: [], stream: false)
    req = Net::HTTP::Post.new(@uri.path)
    req['Content-Type'] = 'application/json'
    req['Authorization'] = "Bearer #{@api_key}"
    req.body = JSON.generate({ model: @config['model'], messages:, tools:, stream: stream })
    req
  end
end
