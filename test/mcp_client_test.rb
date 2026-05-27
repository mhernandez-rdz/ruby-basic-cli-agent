# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'json'
require 'mcp_client'

class McpClientTest < Minitest::Test
  SERVER = File.expand_path('../test/mcp_server.rb', __dir__)

  def setup
    @client = McpClient.new('test', 'ruby', args: [SERVER])
  end

  def teardown
    @client.close
  end

  def test_list_tools_returns_tools
    tools = @client.list_tools
    assert_equal 2, tools.length
  end

  def test_list_tools_returns_tool_names
    names = @client.list_tools.map { |t| t['name'] }
    assert_includes names, 'echo'
    assert_includes names, 'reverse'
  end

  def test_list_tools_returns_descriptions
    tool = @client.list_tools.find { |t| t['name'] == 'echo' }
    assert_equal 'Echoes the input back', tool['description']
  end

  def test_list_tools_returns_input_schema
    tool = @client.list_tools.find { |t| t['name'] == 'echo' }
    assert_equal 'object', tool['inputSchema']['type']
    assert_includes tool['inputSchema']['properties'].keys, 'message'
  end

  def test_call_tool_echo
    result = @client.call_tool('echo', { 'message' => 'hello world' })
    assert_equal 'hello world', result
  end

  def test_call_tool_reverse
    result = @client.call_tool('reverse', { 'text' => 'ruby' })
    assert_equal 'ybur', result
  end

  def test_multiple_calls_use_sequential_ids
    result1 = @client.call_tool('echo', { 'message' => 'first' })
    result2 = @client.call_tool('echo', { 'message' => 'second' })
    assert_equal 'first', result1
    assert_equal 'second', result2
  end
end
