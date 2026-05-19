# frozen_string_literal: true

require_relative 'test_helper'
require 'sqlite3'
require 'memory'

class MemoryTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @memory = Memory.new(File.join(@dir, 'test.db'))
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_create_session_returns_integer_id
    id = @memory.create_session
    assert_kind_of Integer, id
    assert id > 0
  end

  def test_create_session_ids_are_unique
    id1 = @memory.create_session
    id2 = @memory.create_session
    refute_equal id1, id2
  end

  def test_save_and_load_messages
    session_id = @memory.create_session
    @memory.save_message(session_id, 'user', 'hello')
    @memory.save_message(session_id, 'assistant', 'hi there')

    messages = @memory.load_messages(session_id)
    assert_equal 2, messages.length
    assert_equal 'user', messages[0]['role']
    assert_equal 'hello', messages[0]['content']
    assert_equal 'assistant', messages[1]['role']
    assert_equal 'hi there', messages[1]['content']
  end

  def test_load_messages_returns_in_insertion_order
    session_id = @memory.create_session
    @memory.save_message(session_id, 'user', 'first')
    @memory.save_message(session_id, 'assistant', 'second')
    @memory.save_message(session_id, 'user', 'third')

    contents = @memory.load_messages(session_id).map { |m| m['content'] }
    assert_equal ['first', 'second', 'third'], contents
  end

  def test_load_messages_isolates_by_session
    session1 = @memory.create_session
    session2 = @memory.create_session
    @memory.save_message(session1, 'user', 'session 1')
    @memory.save_message(session2, 'user', 'session 2')

    messages = @memory.load_messages(session1)
    assert_equal 1, messages.length
    assert_equal 'session 1', messages[0]['content']
  end

  def test_load_messages_returns_empty_for_unknown_session
    messages = @memory.load_messages(999)
    assert_empty messages
  end

  def test_list_sessions_returns_all_sessions
    @memory.create_session
    @memory.create_session
    assert_equal 2, @memory.list_sessions.length
  end

  def test_list_sessions_uses_first_user_message_as_preview
    session_id = @memory.create_session
    @memory.save_message(session_id, 'assistant', 'ignored')
    @memory.save_message(session_id, 'user', 'hello world')

    sessions = @memory.list_sessions
    assert_equal 'hello world', sessions.first['content']
  end

  def test_list_sessions_returns_empty_when_no_sessions
    assert_empty @memory.list_sessions
  end

  def test_timestamps_are_iso8601
    session_id = @memory.create_session
    @memory.save_message(session_id, 'user', 'hello')

    session = @memory.list_sessions.first
    message = @memory.load_messages(session_id).first

    assert_match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, session['started_at'])
    assert_match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, message['created_at'])
  end
end
