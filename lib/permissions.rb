# frozen_string_literal: true

require 'yaml'

class Permissions # :nodoc:
  def initialize(config_path = '.agent.yml')
    config = YAML.load_file(config_path) rescue {}
    @allowed = config.dig('permissions', 'allowed') || []
  end
  
  def allowed?(command_name)
    @allowed.any? { |pattern| command_name.strip == pattern.strip }
  end
end
