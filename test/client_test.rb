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
end
