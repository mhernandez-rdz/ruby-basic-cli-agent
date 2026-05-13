# frozen_string_literal: true

require_relative '../test_helper'

class WriteFileTest < Minitest::Test
  def setup
    @file = Tempfile.new('write_file_test')
  end

  def teardown
    @file.close
    @file.unlink
  end

  def test_writes_content_to_file
    WriteFile.new.call('path' => @file.path, 'content' => 'Hello!')
    assert_equal 'Hello!', File.read(@file.path)
  end

  def test_returns_confirmation_message
    result = WriteFile.new.call('path' => @file.path, 'content' => 'Hello!')
    assert_match @file.path, result
  end

  def test_tool_name
    assert_equal 'write_file', WriteFile.tool_name
  end
end
