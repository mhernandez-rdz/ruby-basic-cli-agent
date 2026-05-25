# frozen_string_literal: true

require_relative '../test_helper'
require 'net/http'
require 'nokogiri'
require 'tools/web_fetch'

class WebFetchTest < Minitest::Test
  def stub_method(object, method_name, implementation, &block)
    original = object.method(method_name)
    object.define_singleton_method(method_name, &implementation)
    block.call
  ensure
    object.define_singleton_method(method_name, &original)
  end

  def stub_static(html)
    fake_response = Object.new
    fake_response.define_singleton_method(:body) { html }
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_| fake_response }
    stub_method(Net::HTTP, :start, ->(*_args, **_opts, &blk) { blk.call(fake_http) }) { yield }
  end

  def rich_html(words: 200)
    "<html><body><p>#{Array.new(words, 'word').join(' ')}</p></body></html>"
  end

  def test_returns_content_from_static_fetch
    stub_static(rich_html) do
      result = WebFetch.new.call({ 'url' => 'https://example.com' })
      assert_includes result, 'word'
    end
  end

  def test_falls_back_to_ferrum_when_static_content_is_short
    ferrum_called = false
    tool = WebFetch.new
    tool.define_singleton_method(:fetch_static) { |_| 'short' }
    tool.define_singleton_method(:fetch_dynamic) { |_| ferrum_called = true; 'word ' * 200 }
    tool.call({ 'url' => 'https://example.com' })
    assert ferrum_called
  end

  def test_does_not_call_ferrum_when_static_content_is_sufficient
    ferrum_called = false
    tool = WebFetch.new
    tool.define_singleton_method(:fetch_static) { |_| 'word ' * 200 }
    tool.define_singleton_method(:fetch_dynamic) { |_| ferrum_called = true; '' }
    tool.call({ 'url' => 'https://example.com' })
    refute ferrum_called
  end

  def test_truncates_long_content
    stub_static("<html><body><p>#{'word ' * 2000}</p></body></html>") do
      result = WebFetch.new.call({ 'url' => 'https://example.com' })
      assert result.length <= WebFetch::TRUNCATE_AT + 50
      assert_includes result, 'truncated'
    end
  end

  def test_does_not_truncate_short_content
    stub_static(rich_html) do
      result = WebFetch.new.call({ 'url' => 'https://example.com' })
      refute_includes result, 'truncated'
    end
  end

  def test_returns_error_for_invalid_url
    result = WebFetch.new.call({ 'url' => 'not a url' })
    assert_includes result, 'Error'
  end

  def test_returns_error_on_timeout
    stub_method(Net::HTTP, :start, ->(*_args, **_opts) { raise Net::ReadTimeout.new('') }) do
      result = WebFetch.new.call({ 'url' => 'https://example.com' })
      assert_equal 'Error: request timed out', result
    end
  end

  def test_returns_could_not_extract_when_content_empty
    tool = WebFetch.new
    tool.define_singleton_method(:fetch_static) { |_| '' }
    tool.define_singleton_method(:fetch_dynamic) { |_| '' }
    assert_equal 'Could not extract content.', tool.call({ 'url' => 'https://example.com' })
  end
end
