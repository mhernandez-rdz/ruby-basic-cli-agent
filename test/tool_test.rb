# frozen_string_literal: true

require_relative 'test_helper'

class ToolTest < Minitest::Test
  def test_registry_contains_all_tools
    names = Tool.registry.map(&:tool_name)
    assert_includes names, 'read_file'
    assert_includes names, 'list_dir'
    assert_includes names, 'write_file'
    assert_includes names, 'edit_file'
    assert_includes names, 'run_command'
  end

  def test_find_returns_correct_tool
    assert_equal ReadFile, Tool.find('read_file')
    assert_equal ListDir,  Tool.find('list_dir')
  end

  def test_find_returns_nil_for_unknown_tool
    assert_nil Tool.find('nonexistent_tool')
  end

  def test_schemas_returns_array_of_hashes
    schemas = Tool.schemas
    assert_instance_of Array, schemas
    schemas.each do |schema|
      assert_equal 'function', schema[:type]
      assert schema.dig(:function, :name)
    end
  end
end
