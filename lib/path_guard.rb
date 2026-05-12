# frozen_string_literal: true

require 'yaml'

class PathGuard # :nodoc:
  def initialize(config_path = '.agent.yml')
    config = YAML.load_file(config_path) rescue {}
    allowed = config.dig('paths', 'allowed') || ['.']
    @allowed_paths = allowed.map { |p| File.expand_path(p) }
  end

  def safe?(path)
    resolved = File.expand_path(path)
    @allowed_paths.any? { |allowed| resolved.start_with?(allowed) }
  end
end
