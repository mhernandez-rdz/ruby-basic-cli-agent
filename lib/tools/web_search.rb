# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class WebSearch < Tool # :nodoc:
  BASE_URL = 'https://serpapi.com/search'
  DEFAULT_ENGINE = 'google'
  attr_reader :query, :count, :api_key

  def call(args)
    @query = args['query']
    @count = args['count'] || 5
    @api_key = ENV['SERPAPI_KEY'] or return 'Error: SERPAPI_KEY not set'

    uri = setup_uri
    handle_request uri
  rescue Net::OpenTimeout, Net::ReadTimeout
    'Error: search request timed out'
  rescue JSON::ParserError
    'Error: invalid response from search API'
  end

  class << self
    def tool_name
      'web_search'
    end

    def schema # rubocop:disable Metrics/MethodLength
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Search the web using Google. Returns top result titles, links and snippets.',
          parameters: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'Search query' },
              count: { type: 'integer', description: 'Number of results to return (default 5)', default: 5 }
            },
            required: ['query']
          }
        }
      }
    end
  end

  private

  def setup_uri
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form({ q: query, api_key: api_key, num: count, engine: DEFAULT_ENGINE })
    uri
  end

  def handle_request(uri)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 15) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    body = JSON.parse(response.body)
    results = body['organic_results'] || []
    return 'No results found' if results.empty?

    format_result results
  end

  def format_result(results)
    results.first(count).map.with_index(1) { |r, i| "#{i}. #{r['title']}\n  #{r['link']}\n  #{r['snippet']}" }
                            .join("\n\n")
  end
end
