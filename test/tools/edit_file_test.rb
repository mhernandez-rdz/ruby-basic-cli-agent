# frozen_string_literal: true

require_relative '../test_helper'

class EditFileTest < Minitest::Test
  def setup
    @file = Tempfile.new('edit_file_test')
    @file.write('Hello Miguel, how are you?')
    @file.flush
  end

  def teardown
    @file.close
    @file.unlink
  end

  def test_replaces_text_in_file
    EditFile.new.call('path' => @file.path, 'old_str' => 'Miguel', 'new_str' => 'Aaron')
    assert_equal 'Hello Aaron, how are you?', File.read(@file.path)
  end

  def test_returns_ok_on_success
    result = EditFile.new.call('path' => @file.path, 'old_str' => 'Miguel', 'new_str' => 'Aaron')
    assert_equal 'OK', result
  end

  def test_raises_when_old_str_not_found
    assert_raises(RuntimeError) do
      EditFile.new.call('path' => @file.path, 'old_str' => 'nonexistent', 'new_str' => 'replacement')
    end
  end

  def test_raises_for_missing_file
    assert_raises(Errno::ENOENT) do
      EditFile.new.call('path' => '/nonexistent/file.txt', 'old_str' => 'a', 'new_str' => 'b')
    end
  end

  def test_tool_name
    assert_equal 'edit_file', EditFile.tool_name
  end
end
