# frozen_string_literal: true

require_relative '../test_helper'

class ListDirTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    File.write(File.join(@dir, 'file_a.txt'), 'a')
    File.write(File.join(@dir, 'file_b.txt'), 'b')
    File.write(File.join(@dir, '.hidden'), 'hidden')
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_lists_files_in_directory
    result = ListDir.new.call('path' => @dir)
    assert_includes result, 'file_a.txt'
    assert_includes result, 'file_b.txt'
  end

  def test_excludes_dot_entries
    entries = ListDir.new.call('path' => @dir).split("\n")
    refute_includes entries, '.'
    refute_includes entries, '..'
  end

  def test_includes_hidden_files
    entries = ListDir.new.call('path' => @dir).split("\n")
    assert_includes entries, '.hidden'
  end

  def test_raises_for_missing_directory
    assert_raises(Errno::ENOENT) do
      ListDir.new.call('path' => '/nonexistent/dir')
    end
  end

  def test_tool_name
    assert_equal 'list_dir', ListDir.tool_name
  end
end
