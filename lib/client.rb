# frozen_string_literal: true

class Client # :nodoc:
  MODEL = 'deepseek-v4-flash'
  ENDPOINT = 'https://opencode.ai/zen/go/v1/chat/completions'

  def initialize
    @api_key = ENV['OPENCODE_API_KEY']
    @http = build_http
  end

  def chat(messages, tools: [])
    raw_chat(messages, tools:)&.dig('content')
  end

  def raw_chat(messages, tools: [])
    request = build_request(messages, tools:)
    response = @http.request(request)
    body = JSON.parse(response.body)
    body.dig("choices", 0, "message") or raise "Unexpected API response: #{body}"
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise 'API timeout - check your connection...'
  rescue Errno::ECONNREFUSED
    raise 'Could not connect to API'
  end

  private

  def build_http
    uri = URI(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 60
    http
  end

  def build_request(messages, tools: [])
    uri = URI(ENDPOINT)
    req = Net::HTTP::Post.new(uri.path)
    req['Content-Type'] = 'application/json'
    req['Authorization'] = "Bearer #{@api_key}"
    req.body = JSON.generate({ model: MODEL, messages:, tools: })
    req
  end
end
