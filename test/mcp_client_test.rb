# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'json'
require 'mcp_client'

class McpClientTest < Minitest::Test
  SERVER = File.expand_path('../test/mcp_server.rb', __dir__)

  def setup
    @client = McpClient::Stdio.new('test', 'ruby', args: [SERVER])
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

class McpClientFactoryTest < Minitest::Test
  SERVER = File.expand_path('../test/mcp_server.rb', __dir__)

  def test_build_returns_stdio_when_no_transport
    config = { 'name' => 'test', 'command' => 'ruby', 'args' => [SERVER] }
    client = McpClient.build(config)
    assert_instance_of McpClient::Stdio, client
  ensure
    client&.close
  end

  def test_build_returns_stdio_when_transport_is_stdio
    config = { 'name' => 'test', 'transport' => 'stdio', 'command' => 'ruby', 'args' => [SERVER] }
    client = McpClient.build(config)
    assert_instance_of McpClient::Stdio, client
  ensure
    client&.close
  end

  def test_build_dispatches_to_http_for_http_transport
    spy = Class.new do
      attr_reader :name, :url, :auth_token
      def initialize(name, url, auth_token: nil)
        @name = name
        @url = url
        @auth_token = auth_token
      end
    end

    original = McpClient.send(:remove_const, :Http)
    McpClient.const_set(:Http, spy)

    config = { 'name' => 'remote', 'transport' => 'http', 'url' => 'http://example.com', 'auth_token' => 'tok' }
    client = McpClient.build(config)

    assert_instance_of spy, client
    assert_equal 'remote', client.name
    assert_equal 'http://example.com', client.url
    assert_equal 'tok', client.auth_token
  ensure
    McpClient.send(:remove_const, :Http)
    McpClient.const_set(:Http, original)
  end
end

class McpClientHttpParseTest < Minitest::Test
  def setup
    @client = McpClient::Http.allocate
    @client.instance_variable_set(:@endpoint_queue, Queue.new)
    @client.instance_variable_set(:@queue, Queue.new)
  end

  def test_parses_endpoint_event
    @client.send(:parse_sse_event, "event: endpoint\ndata: /message?sessionId=abc123")
    result = @client.instance_variable_get(:@endpoint_queue).pop(true)
    assert_equal '/message?sessionId=abc123', result
  end

  def test_parses_message_event
    payload = '{"jsonrpc":"2.0","id":1,"result":{"tools":[]}}'
    @client.send(:parse_sse_event, "event: message\ndata: #{payload}")
    msg = @client.instance_variable_get(:@queue).pop(true)
    assert_equal 1, msg['id']
    assert_equal [], msg.dig('result', 'tools')
  end

  def test_ignores_heartbeat_comment
    @client.send(:parse_sse_event, ': heartbeat')
    assert_predicate @client.instance_variable_get(:@endpoint_queue), :empty?
    assert_predicate @client.instance_variable_get(:@queue), :empty?
  end

  def test_ignores_unknown_event_type
    @client.send(:parse_sse_event, "event: ping\ndata: {}")
    assert_predicate @client.instance_variable_get(:@endpoint_queue), :empty?
    assert_predicate @client.instance_variable_get(:@queue), :empty?
  end
end
