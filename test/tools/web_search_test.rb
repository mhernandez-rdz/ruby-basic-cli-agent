# frozen_string_literal: true

require_relative '../test_helper'
require 'net/http'
require 'json'
require 'tools/web_search'

class WebSearchTest < Minitest::Test
  def setup
    ENV['SERPAPI_KEY'] = 'test-key'
  end

  def teardown
    ENV.delete('SERPAPI_KEY')
  end

  def stub_method(object, method_name, implementation, &block)
    original = object.method(method_name)
    object.define_singleton_method(method_name, &implementation)
    block.call
  ensure
    object.define_singleton_method(method_name, &original)
  end

  def with_fake_http(body, &block)
    fake_response = Struct.new(:body).new(JSON.generate(body))
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_| fake_response }
    stub_method(Net::HTTP, :start, ->(*_args, **_opts, &blk) { blk.call(fake_http) }, &block)
  end

  def test_returns_formatted_results
    body = {
      'organic_results' => [
        { 'title' => 'Result One', 'link' => 'https://one.com', 'snippet' => 'First snippet' },
        { 'title' => 'Result Two', 'link' => 'https://two.com', 'snippet' => 'Second snippet' }
      ]
    }
    with_fake_http(body) do
      result = WebSearch.new.call({ 'query' => 'ruby' })
      assert_includes result, '1. Result One'
      assert_includes result, 'https://one.com'
      assert_includes result, 'First snippet'
      assert_includes result, '2. Result Two'
    end
  end

  def test_returns_no_results_message_when_empty
    with_fake_http({ 'organic_results' => [] }) do
      assert_equal 'No results found', WebSearch.new.call({ 'query' => 'ruby' })
    end
  end

  def test_returns_error_when_api_key_not_set
    ENV.delete('SERPAPI_KEY')
    assert_equal 'Error: SERPAPI_KEY not set', WebSearch.new.call({ 'query' => 'ruby' })
  end

  def test_respects_count_parameter
    results = (1..10).map { |i| { 'title' => "R#{i}", 'link' => "https://r#{i}.com", 'snippet' => "s#{i}" } }
    with_fake_http({ 'organic_results' => results }) do
      result = WebSearch.new.call({ 'query' => 'ruby', 'count' => 3 })
      assert_includes result, '3. R3'
      refute_includes result, '4. R4'
    end
  end

  def test_handles_timeout
    stub_method(Net::HTTP, :start, ->(*_args, **_opts) { raise Net::ReadTimeout.new('') }) do
      assert_equal 'Error: search request timed out', WebSearch.new.call({ 'query' => 'ruby' })
    end
  end

  def test_handles_invalid_json_response
    fake_response = Struct.new(:body).new('not json')
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_| fake_response }
    stub_method(Net::HTTP, :start, ->(*_args, **_opts, &blk) { blk.call(fake_http) }) do
      assert_equal 'Error: invalid response from search API', WebSearch.new.call({ 'query' => 'ruby' })
    end
  end
end
