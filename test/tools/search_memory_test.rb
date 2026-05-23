# frozen_string_literal: true

require_relative '../test_helper'
require 'memory'
require 'tools/search_memory'

class SearchMemoryTest < Minitest::Test
  def setup
    @fake_memory = Object.new
    fake = @fake_memory
    Memory.define_singleton_method(:new) { |_path = nil| fake }
  end

  def teardown
    Memory.singleton_class.remove_method(:new)
  end

  def stub_search(results)
    @fake_memory.define_singleton_method(:search_messages) { |**_| results }
  end

  def make_result(content:, role: 'user', session_id: 1, created_at: '2024-01-01T00:00:00')
    { message: { 'role' => role, 'content' => content }, session_id:, created_at: }
  end

  def test_returns_no_memories_message_when_empty
    stub_search([])
    result = SearchMemory.new.call({ 'query' => 'ruby' })
    assert_equal 'No relevant memories found.', result
  end

  def test_formats_result_with_index_and_metadata
    stub_search([make_result(content: 'hello ruby', session_id: 3, created_at: '2024-01-01T10:00:00')])
    result = SearchMemory.new.call({ 'query' => 'ruby' })
    assert_includes result, '[1]'
    assert_includes result, 'session 3'
    assert_includes result, '2024-01-01T10:00:00'
    assert_includes result, 'user: hello ruby'
  end

  def test_formats_multiple_results_with_sequential_indexes
    stub_search([make_result(content: 'first'), make_result(content: 'second')])
    result = SearchMemory.new.call({ 'query' => 'hello' })
    assert_includes result, '[1]'
    assert_includes result, '[2]'
  end

  def test_passes_query_to_memory
    received = {}
    @fake_memory.define_singleton_method(:search_messages) do |**args|
      received = args
      []
    end
    SearchMemory.new.call({ 'query' => 'sqlite', 'limit' => 3 })
    assert_equal 'sqlite', received[:query]
    assert_equal 3, received[:limit]
  end

  def test_passes_tags_to_memory
    received = {}
    @fake_memory.define_singleton_method(:search_messages) do |**args|
      received = args
      []
    end
    SearchMemory.new.call({ 'tags' => ['ruby', 'testing'] })
    assert_equal ['ruby', 'testing'], received[:tags]
  end

  def test_defaults_limit_to_5
    received = {}
    @fake_memory.define_singleton_method(:search_messages) do |**args|
      received = args
      []
    end
    SearchMemory.new.call({ 'query' => 'hello' })
    assert_equal 5, received[:limit]
  end
end
