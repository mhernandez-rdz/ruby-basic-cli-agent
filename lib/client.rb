class Client
  MODEL = 'deepseek-v4-flash'
  ENDPOINT = 'https://opencode.ai/zen/go/v1/chat/completions'

  def initialize
    @api_key = ENV['OPENCODE_API_KEY']
    @http = build_http
  end

  def chat(messages)
    request = build_request(messages)
    response = @http.request(request)
    body = JSON.parse(response.body)
    body.dig("choices", 0, "message", "content")
  end

  private

  def build_http
    uri = URI(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http
  end

  def build_request(messages)
    uri = URI(ENDPOINT)
    req = Net::HTTP::Post.new(uri.path)
    req['Content-Type'] = 'application/json'
    req['Authorization'] = "Bearer #{@api_key}"
    req.body = JSON.generate({ model: MODEL, messages: })
    req
  end
end
