# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'json'
require 'mcp_client'
require 'mcp_server_registry'

class McpServerRegistryTest < Minitest::Test
  SERVER = File.expand_path('../test/mcp_server.rb', __dir__)

  def setup
    @initial_registry = Tool.registry.dup
  end

  def teardown
    Tool.registry.replace(@initial_registry)
  end

  def config_with_server(name: 'test')
    { 'mcp_servers' => [{ 'name' => name, 'command' => 'ruby', 'args' => [SERVER] }] }
  end

  def test_registers_tools_from_server
    registry = McpServerRegistry.new(config_with_server)
    names = Tool.registry.map(&:tool_name)
    assert_includes names, 'test__echo'
    assert_includes names, 'test__reverse'
  ensure
    registry.close_all
  end

  def test_registered_tools_have_valid_schema
    registry = McpServerRegistry.new(config_with_server)
    tool = Tool.find('test__echo')
    schema = tool.schema
    assert_equal 'function', schema[:type]
    assert_equal 'test__echo', schema[:function][:name]
  ensure
    registry.close_all
  end

  def test_registered_tools_are_callable
    registry = McpServerRegistry.new(config_with_server)
    result = Tool.find('test__echo').new.call({ 'message' => 'hello' })
    assert_equal 'hello', result
  ensure
    registry.close_all
  end

  def test_supports_multiple_servers
    config = {
      'mcp_servers' => [
        { 'name' => 'server_a', 'command' => 'ruby', 'args' => [SERVER] },
        { 'name' => 'server_b', 'command' => 'ruby', 'args' => [SERVER] }
      ]
    }
    registry = McpServerRegistry.new(config)
    names = Tool.registry.map(&:tool_name)
    assert_includes names, 'server_a__echo'
    assert_includes names, 'server_b__echo'
  ensure
    registry.close_all
  end

  def test_empty_config_registers_no_tools
    initial_count = Tool.registry.length
    registry = McpServerRegistry.new({})
    assert_equal initial_count, Tool.registry.length
  ensure
    registry.close_all
  end

  def test_close_all_terminates_server_processes
    registry = McpServerRegistry.new(config_with_server)
    registry.close_all
    # after close, calling list_tools should raise since the process is dead
    client = registry.instance_variable_get(:@clients)['test']
    assert_raises(IOError, Errno::EPIPE) { client.list_tools }
  end
end
