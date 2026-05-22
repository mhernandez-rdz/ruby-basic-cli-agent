# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tagger'
require 'memory'

class TaggerTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @memory = Memory.new(File.join(@dir, 'test.db'))
    @session_id = @memory.create_session
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_tag_async_saves_tags_to_memory
    msg_id = @memory.save_message(@session_id, { 'role' => 'user', 'content' => 'hello ruby' })

    client = Object.new
    client.define_singleton_method(:chat) { |_| '["ruby", "testing"]' }

    tagger = Tagger.new(client, @memory)
    tagger.tag_async(msg_id, 'hello ruby').join

    tags = @memory.list_tags.map { |t| t['name'] }
    assert_includes tags, 'ruby'
    assert_includes tags, 'testing'
  end

  def test_tag_async_passes_existing_tags_to_client
    first_id = @memory.save_message(@session_id, { 'role' => 'user', 'content' => 'first' })
    @memory.save_tags(first_id, ['existing-tag'])
    msg_id = @memory.save_message(@session_id, { 'role' => 'user', 'content' => 'second' })

    received_messages = nil
    client = Object.new
    client.define_singleton_method(:chat) do |messages|
      received_messages = messages
      '["existing-tag"]'
    end

    tagger = Tagger.new(client, @memory)
    tagger.tag_async(msg_id, 'second').join

    user_message = received_messages.find { |m| m[:role] == 'user' }
    assert_includes user_message[:content], 'existing-tag'
  end

  def test_tag_async_does_not_raise_on_client_error
    msg_id = @memory.save_message(@session_id, { 'role' => 'user', 'content' => 'hello' })

    client = Object.new
    client.define_singleton_method(:chat) { |_| raise 'network error' }

    tagger = Tagger.new(client, @memory)
    assert_silent { tagger.tag_async(msg_id, 'hello').join }
  end

  def test_tag_async_does_not_raise_on_invalid_json
    msg_id = @memory.save_message(@session_id, { 'role' => 'user', 'content' => 'hello' })

    client = Object.new
    client.define_singleton_method(:chat) { |_| 'not valid json' }

    tagger = Tagger.new(client, @memory)
    assert_silent { tagger.tag_async(msg_id, 'hello').join }
  end

  def test_tag_async_saves_nothing_on_error
    msg_id = @memory.save_message(@session_id, { 'role' => 'user', 'content' => 'hello' })

    client = Object.new
    client.define_singleton_method(:chat) { |_| raise 'fail' }

    tagger = Tagger.new(client, @memory)
    tagger.tag_async(msg_id, 'hello').join

    assert_empty @memory.list_tags
  end
end
