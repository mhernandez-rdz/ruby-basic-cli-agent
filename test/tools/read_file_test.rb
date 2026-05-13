# frozen_string_literal: true

require_relative '../test_helper'

class ReadFileTest < Minitest::Test
  def setup
    @file = Tempfile.new('read_file_test')
    @file.write('Hello, world!')
    @file.flush
  end

  def teardown
    @file.close
    @file.unlink
  end

  def test_reads_file_content
    result = ReadFile.new.call('path' => @file.path)
    assert_equal 'Hello, world!', result
  end

  def test_raises_for_missing_file
    assert_raises(Errno::ENOENT) do
      ReadFile.new.call('path' => '/nonexistent/file.txt')
    end
  end

  def test_tool_name
    assert_equal 'read_file', ReadFile.tool_name
  end
end
