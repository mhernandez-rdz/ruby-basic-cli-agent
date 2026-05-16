# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'yaml'

require_relative 'utils/config'

class Setup # :nodoc:
  class << self
    PLANS = {
      'go' => { label: 'OpenCode Go', base_url: 'https://opencode.ai/zen/go/v1' },
      'zen' => { label: 'OpenCode Zen', base_url: 'https://opencode.ai/zen/v1' }
    }.freeze

    def run
      config = Config.read_config
      plan_key, plan = handle_plan
      raise 'Invalid Plan' unless plan

      model = handle_models(plan)
      raise 'Invalid model' unless model

      new_config = config.merge('plan' => plan_key, 'model' => model, 'base_url' => plan[:base_url])
      puts "#{plan[:label]} with #{model} selected"
      Config.update_config(new_config)
    end

    private

    def handle_plan
      puts 'Select your plan:'
      PLANS.each_with_index { |(_key, plan), i| puts " [#{i + 1}] #{plan[:label]}\n" }
      print "Choice:\n"
      choice = $stdin.gets&.chomp&.to_i
      PLANS.to_a[choice - 1]
    end

    def handle_models(plan)
      models = fetch_models(plan[:base_url])
      models.each_with_index { |model, i| puts "[#{i + 1}] #{model}" }
      print "Select your model\n"
      model_index = $stdin.gets&.chomp&.to_i
      models[model_index - 1]
    end

    def fetch_models(base_url)
      uri = URI("#{base_url}/models")
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{ENV['OPENCODE_API_KEY']}"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(req)
      JSON.parse(response.body)['data']&.map { |m| m['id'] }
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise 'API timeout - check your connection...'
    rescue Errno::ECONNREFUSED
      raise 'Could not connect to API'
    end
  end
end
