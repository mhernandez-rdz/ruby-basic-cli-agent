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

  def test_excludes_hidden_files_and_dots
    entries = ListDir.new.call('path' => @dir).split("\n")
    refute_includes entries, '.hidden'
    refute_includes entries, '.'
    refute_includes entries, '..'
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
