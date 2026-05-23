# frozen_string_literal: true

require_relative 'test_helper'
require 'net/http'
require 'json'
require 'client'

class ClientTest < Minitest::Test
  FAKE_CONFIG = { 'base_url' => 'https://api.example.com/v1', 'model' => 'test-model' }.freeze

  def setup
    ENV['OPENCODE_API_KEY'] = 'test-key'
  end

  def teardown
    ENV.delete('OPENCODE_API_KEY')
  end

  def stub_method(object, method_name, implementation, &block)
    original = object.method(method_name)
    object.define_singleton_method(method_name, &implementation)
    block.call
  ensure
    object.define_singleton_method(method_name, &original)
  end

  def with_fake_http(response_body, &block)
    fake_response = Struct.new(:body).new(JSON.generate(response_body))
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_| fake_response }

    stub_method(Config, :read_config, -> { FAKE_CONFIG }) do
      stub_method(Net::HTTP, :start, ->(*_args, **_opts, &blk) { blk.call(fake_http) }) do
        block.call
      end
    end
  end

  def test_raw_chat_returns_message_hash
    body = { 'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'hello' } }] }
    with_fake_http(body) do
      client = Client.new
      result = client.raw_chat([{ role: 'user', content: 'hi' }])
      assert_equal 'assistant', result['role']
      assert_equal 'hello', result['content']
    end
  end

  def test_chat_returns_content_string
    body = { 'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'hello' } }] }
    with_fake_http(body) do
      client = Client.new
      result = client.chat([{ role: 'user', content: 'hi' }])
      assert_equal 'hello', result
    end
  end

  def test_raw_chat_raises_on_unexpected_response
    body = { 'error' => 'something went wrong' }
    with_fake_http(body) do
      client = Client.new
      assert_raises(RuntimeError) { client.raw_chat([]) }
    end
  end

  def test_raw_chat_raises_on_timeout
    stub_method(Config, :read_config, -> { FAKE_CONFIG }) do
      stub_method(Net::HTTP, :start, ->(*_args, **_opts) { raise Net::ReadTimeout.new('') }) do
        client = Client.new
        error = assert_raises(RuntimeError) { client.raw_chat([]) }
        assert_match(/timeout/, error.message)
      end
    end
  end

  def test_raw_chat_raises_on_connection_refused
    stub_method(Config, :read_config, -> { FAKE_CONFIG }) do
      stub_method(Net::HTTP, :start, ->(*_args, **_opts) { raise Errno::ECONNREFUSED }) do
        client = Client.new
        error = assert_raises(RuntimeError) { client.raw_chat([]) }
        assert_match(/connect/, error.message)
      end
    end
  end

  def test_initialize_raises_without_config
    stub_method(Config, :read_config, -> { {} }) do
      assert_raises(RuntimeError) { Client.new }
    end
  end

  def with_fake_stream(chunks, &block)
    fake_response = Object.new
    fake_response.define_singleton_method(:read_body) do |&blk|
      chunks.each { |c| blk.call(c) }
    end

    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_req, &blk| blk.call(fake_response) }

    stub_method(Config, :read_config, -> { FAKE_CONFIG }) do
      stub_method(Net::HTTP, :start, ->(*_args, **_opts, &blk) { blk.call(fake_http) }) do
        block.call
      end
    end
  end

  def sse(delta)
    "data: #{JSON.generate({ 'choices' => [{ 'delta' => delta }] })}\n"
  end

  def test_stream_chat_yields_content_chunks
    chunks = [sse({ 'content' => 'hel' }), sse({ 'content' => 'lo' }), "data: [DONE]\n"]
    received = []
    with_fake_stream(chunks) do
      client = Client.new
      client.stream_chat([]) { |c| received << c }
    end
    assert_equal ['hel', 'lo'], received
  end

  def test_stream_chat_returns_assembled_content
    chunks = [sse({ 'content' => 'hel' }), sse({ 'content' => 'lo' }), "data: [DONE]\n"]
    with_fake_stream(chunks) do
      client = Client.new
      result = client.stream_chat([]) { |_| }
      assert_equal 'hello', result['content']
      assert_equal 'assistant', result['role']
    end
  end

  def test_stream_chat_handles_split_chunks
    raw = "data: #{JSON.generate({ 'choices' => [{ 'delta' => { 'content' => 'hello' } }] })}\n"
    half = raw.length / 2
    chunks = [raw[0...half], raw[half..], "data: [DONE]\n"]
    received = []
    with_fake_stream(chunks) do
      client = Client.new
      client.stream_chat([]) { |c| received << c }
    end
    assert_equal ['hello'], received
  end

  def test_stream_chat_assembles_tool_calls
    chunks = [
      sse({ 'tool_calls' => [{ 'index' => 0, 'id' => 'call_1', 'type' => 'function',
                               'function' => { 'name' => 'read_file', 'arguments' => '' } }] }),
      sse({ 'tool_calls' => [{ 'index' => 0, 'id' => '', 'type' => 'function',
                               'function' => { 'name' => '', 'arguments' => '{"path":"x"}' } }] }),
      "data: [DONE]\n"
    ]
    with_fake_stream(chunks) do
      client = Client.new
      result = client.stream_chat([]) { |_| }
      assert_nil result['content']
      assert_equal 1, result['tool_calls'].length
      tc = result['tool_calls'].first
      assert_equal 'call_1', tc['id']
      assert_equal 'read_file', tc['function']['name']
      assert_equal '{"path":"x"}', tc['function']['arguments']
    end
  end

  def test_stream_chat_raises_on_timeout
    stub_method(Config, :read_config, -> { FAKE_CONFIG }) do
      stub_method(Net::HTTP, :start, ->(*_args, **_opts) { raise Net::ReadTimeout.new('') }) do
        client = Client.new
        error = assert_raises(RuntimeError) { client.stream_chat([]) { |_| } }
        assert_match(/timeout/, error.message)
      end
    end
  end
end
