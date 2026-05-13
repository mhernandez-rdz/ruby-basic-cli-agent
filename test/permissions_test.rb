# frozen_string_literal: true

require_relative 'test_helper'

class PermissionsTest < Minitest::Test
  def setup
    @config_file = Tempfile.new(['.agent', '.yml'])
    @config_file.write(<<~YAML)
      permissions:
        allowed:
          - "git status"
          - "ls ."
          - "pwd"
    YAML
    @config_file.flush
    @permissions = Permissions.new(@config_file.path)
  end

  def teardown
    @config_file.close
    @config_file.unlink
  end

  def test_exact_match_is_allowed
    assert @permissions.allowed?('git status')
    assert @permissions.allowed?('ls .')
    assert @permissions.allowed?('pwd')
  end

  def test_partial_match_is_not_allowed
    refute @permissions.allowed?('ls -la /etc')
    refute @permissions.allowed?('git status && rm -rf /')
  end

  def test_unknown_command_is_not_allowed
    refute @permissions.allowed?('rm -rf /')
    refute @permissions.allowed?('sudo su')
  end

  def test_defaults_to_empty_when_config_missing
    permissions = Permissions.new('/nonexistent/.agent.yml')
    refute permissions.allowed?('ls .')
  end
end
