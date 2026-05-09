# frozen_string_literal: true

require 'yaml'

class Permissions
  def initialize(config_path = '.agent.yml')
    config = YAML.load_file(config_path) rescue {}
    @allowed = config.dig('permissions', 'allowed') || []
  end
  
  def allowed?(command)
    @allowed.any? { |pattern| command.include?(pattern) }
  end
end
