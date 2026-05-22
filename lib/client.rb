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

  private

  def build_request(messages, tools: [])
    req = Net::HTTP::Post.new(@uri.path)
    req['Content-Type'] = 'application/json'
    req['Authorization'] = "Bearer #{@api_key}"
    req.body = JSON.generate({ model: @config['model'], messages:, tools: })
    req
  end
end
