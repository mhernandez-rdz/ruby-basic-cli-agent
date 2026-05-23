# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'
require 'tools/grep'

class GrepTest < Minitest::Test
  def stub_capture3(stdout, stderr, status)
    original = Open3.method(:capture3)
    Open3.define_singleton_method(:capture3) { |_cmd| [stdout, stderr, status] }
    yield
  ensure
    Open3.define_singleton_method(:capture3) { |*a, **k, &b| original.call(*a, **k, &b) }
  end

  def fake_status(success)
    s = Object.new
    s.define_singleton_method(:success?) { success }
    s
  end

  def grep_with(rg:, stdout:, stderr: '', success: true)
    tool = Grep.new
    tool.define_singleton_method(:rg?) { rg }
    stub_capture3(stdout, stderr, fake_status(success)) { yield tool }
  end

  def test_returns_matching_lines
    grep_with(rg: true, stdout: "lib/client.rb:10:  description: 'hello'\n") do |tool|
      result = tool.call({ 'pattern' => 'description' })
      assert_includes result, 'lib/client.rb:10'
    end
  end

  def test_returns_no_matches_message_when_empty_and_success
    grep_with(rg: true, stdout: '', success: true) do |tool|
      assert_equal 'No matches found', tool.call({ 'pattern' => 'description' })
    end
  end

  def test_returns_stderr_on_failure_with_empty_stdout
    grep_with(rg: true, stdout: '', stderr: 'some error', success: false) do |tool|
      assert_equal 'some error', tool.call({ 'pattern' => 'description' })
    end
  end

  def test_truncates_output_to_50_lines
    stdout = (1..60).map { |i| "file.rb:#{i}: match\n" }.join
    grep_with(rg: true, stdout:) do |tool|
      result = tool.call({ 'pattern' => 'match' })
      assert_equal 50, result.lines.count { |l| l.include?('match') }
      assert_includes result, '(results truncated)'
    end
  end

  def test_does_not_truncate_when_50_lines_or_fewer
    stdout = (1..50).map { |i| "file.rb:#{i}: match\n" }.join
    grep_with(rg: true, stdout:) do |tool|
      refute_includes tool.call({ 'pattern' => 'match' }), 'truncated'
    end
  end

  def test_uses_glob_flag_with_rg_when_include_given
    captured_cmd = nil
    original = Open3.method(:capture3)
    status = fake_status(true)
    Open3.define_singleton_method(:capture3) do |cmd|
      captured_cmd = cmd
      ["result\n", '', status]
    end
    tool = Grep.new
    tool.define_singleton_method(:rg?) { true }
    tool.call({ 'pattern' => 'foo', 'include' => 'rb' })
    assert_includes captured_cmd, "-g '*.rb'"
  ensure
    Open3.define_singleton_method(:capture3) { |*a, **k, &b| original.call(*a, **k, &b) }
  end

  def test_uses_include_flag_with_grep_when_include_given
    captured_cmd = nil
    original = Open3.method(:capture3)
    status = fake_status(true)
    Open3.define_singleton_method(:capture3) do |cmd|
      captured_cmd = cmd
      ["result\n", '', status]
    end
    tool = Grep.new
    tool.define_singleton_method(:rg?) { false }
    tool.call({ 'pattern' => 'foo', 'include' => 'rb' })
    assert_includes captured_cmd, "--include='*.rb'"
  ensure
    Open3.define_singleton_method(:capture3) { |*a, **k, &b| original.call(*a, **k, &b) }
  end

  def test_uses_given_path
    captured_cmd = nil
    original = Open3.method(:capture3)
    status = fake_status(true)
    Open3.define_singleton_method(:capture3) do |cmd|
      captured_cmd = cmd
      ["result\n", '', status]
    end
    tool = Grep.new
    tool.define_singleton_method(:rg?) { true }
    tool.call({ 'pattern' => 'foo', 'path' => 'lib/' })
    assert_includes captured_cmd, 'lib/'
  ensure
    Open3.define_singleton_method(:capture3) { |*a, **k, &b| original.call(*a, **k, &b) }
  end
end
