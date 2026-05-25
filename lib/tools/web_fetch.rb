# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'ferrum'

class WebFetch < Tool # :nodoc:
  MIN_WORDS = 150
  TRUNCATE_AT = 3000

  def call(args) # rubocop:disable Metrics/MethodLength
    url = args['url']
    content = fetch_static(url)
    content = fetch_dynamic(url) if content.split.length < MIN_WORDS
    return 'Could not extract content.' if content.strip.empty?

    content.length > TRUNCATE_AT ? "#{content[0...TRUNCATE_AT]}\n (truncated)" : content
  rescue URI::InvalidURIError
    "Error: invalid URL '#{url}'"
  rescue Net::OpenTimeout, Net::ReadTimeout
    'Error: request timed out'
  rescue Ferrum::Error => e
    "Error: browser render failed - #{e.message}"
  rescue StandardError => e
    "Error: #{e.message}"
  end

  class << self
    def tool_name
      'web_fetch'
    end

    def schema
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Fetch and extract readable text content from a URL.'\
                       ' Falls back to a headless browser if static fetch returns too little content.',
          parameters: {
            type: 'object',
            properties: {
              url: { type: 'string', description: 'URL to fetch' }
            },
            required: ['url']
          }
        }
      }
    end
  end

  private

  def fetch_static(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 60) do |http|
      response = http.request(request)
      parse_html response.body
    end
  end

  def fetch_dynamic(url)
    browser = Ferrum::Browser.new(headless: true)
    browser.goto(url)
    html = browser.body
    browser.quit
    parse_html html
  end

  def parse_html(html)
    doc = Nokogiri::HTML(html)
    doc.css('script, style, nav, footer, header, noscript').remove
    doc.text.gsub(/\s+/, ' ').strip
  end
end
