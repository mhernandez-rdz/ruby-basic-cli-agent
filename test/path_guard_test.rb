# frozen_string_literal: true

require_relative 'test_helper'

class PathGuardTest < Minitest::Test
  def setup
    @working_dir = Dir.pwd
    @config_file = Tempfile.new(['.agent', '.yml'])
    @config_file.write(<<~YAML)
      paths:
        allowed:
          - "."
    YAML
    @config_file.flush
    @guard = PathGuard.new(@config_file.path)
  end

  def teardown
    @config_file.close
    @config_file.unlink
  end

  def test_path_within_working_dir_is_safe
    assert @guard.safe?(@working_dir)
    assert @guard.safe?(File.join(@working_dir, 'lib'))
    assert @guard.safe?(File.join(@working_dir, 'lib', 'tool.rb'))
  end

  def test_path_outside_working_dir_is_unsafe
    refute @guard.safe?('/etc/passwd')
    refute @guard.safe?('/home')
    refute @guard.safe?('/tmp')
  end

  def test_path_traversal_is_blocked
    refute @guard.safe?(File.join(@working_dir, '../../../etc/passwd'))
  end

  def test_additional_allowed_path_in_config
    config_file = Tempfile.new(['.agent', '.yml'])
    config_file.write(<<~YAML)
      paths:
        allowed:
          - "."
          - "/tmp"
    YAML
    config_file.flush
    guard = PathGuard.new(config_file.path)

    assert guard.safe?('/tmp/somefile.txt')
    refute guard.safe?('/etc/passwd')
  ensure
    config_file.close
    config_file.unlink
  end
end
