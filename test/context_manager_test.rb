# frozen_string_literal: true

require_relative 'test_helper'

class FakeClient
  attr_reader :chat_called

  def initialize(summary = 'This is a summary.')
    @summary = summary
    @chat_called = false
  end

  def chat(_messages)
    @chat_called = true
    @summary
  end
end

class ContextManagerTest < Minitest::Test
  def setup
    @client = FakeClient.new
    @system_prompt = 'You are a test assistant.'
    @context = ContextManager.new(@client, system_prompt: @system_prompt)
  end

  def test_initializes_with_system_prompt
    assert_equal 1, @context.messages.length
    assert_equal 'system', @context.messages.first['role']
    assert_equal @system_prompt, @context.messages.first['content']
  end

  def test_add_appends_message
    @context.add({ role: 'user', content: 'hello' })
    assert_equal 2, @context.messages.length
  end

  def test_add_normalizes_symbol_keys_to_strings
    @context.add({ role: 'user', content: 'hello' })
    msg = @context.messages.last
    assert msg.key?('role'), 'expected string key "role"'
    assert msg.key?('content'), 'expected string key "content"'
  end

  def test_add_user_message_appends_message
    @context.add_user_message({ role: 'user', content: 'hello' })
    assert_equal 2, @context.messages.length
    assert_equal 'hello', @context.messages.last['content']
  end

  def test_add_user_message_normalizes_keys
    @context.add_user_message({ role: 'user', content: 'hello' })
    msg = @context.messages.last
    assert msg.key?('role'), 'expected string key "role"'
    assert msg.key?('content'), 'expected string key "content"'
  end

  def test_no_compaction_below_threshold
    ContextManager::THRESHOLD.times do |i|
      @context.add({ role: 'user', content: "message #{i}" })
    end
    refute @client.chat_called
  end

  def test_compaction_triggered_above_threshold
    (ContextManager::THRESHOLD + 1).times do |i|
      @context.add({ role: 'user', content: "message #{i}" })
    end
    @context.add_user_message({ role: 'user', content: 'trigger' })
    assert @client.chat_called
    assert @context.messages.any? { |m| m['content']&.include?('summary') }
  end

  def test_compaction_keeps_recent_messages
    (ContextManager::THRESHOLD + 1).times do |i|
      @context.add({ role: 'user', content: "message #{i}" })
    end
    @context.add_user_message({ role: 'user', content: 'trigger' })
    recent_content = @context.messages.map { |m| m['content'] }
    assert_includes recent_content, "message #{ContextManager::THRESHOLD}"
  end

  def test_compaction_preserves_system_prompt
    (ContextManager::THRESHOLD + 1).times do |i|
      @context.add({ role: 'user', content: "message #{i}" })
    end
    @context.add_user_message({ role: 'user', content: 'trigger' })
    assert_equal 'system', @context.messages.first['role']
    assert_equal @system_prompt, @context.messages.first['content']
  end
end
