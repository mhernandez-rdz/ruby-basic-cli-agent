# frozen_string_literal: true

require_relative '../test_helper'

class RunCommandTest < Minitest::Test
  def test_returns_stdout
    result = RunCommand.new.call('command' => 'echo hello')
    assert_equal "hello\n", result
  end

  def test_returns_stderr_when_stdout_empty
    result = RunCommand.new.call('command' => 'ls /nonexistent_dir_xyz')
    refute_empty result
  end

  def test_tool_name
    assert_equal 'run_command', RunCommand.tool_name
  end
end
