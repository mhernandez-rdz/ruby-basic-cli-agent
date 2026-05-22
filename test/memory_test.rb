# frozen_string_literal: true

require_relative 'test_helper'
require 'sqlite3'
require 'json'
require 'memory'

class MemoryTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @memory = Memory.new(File.join(@dir, 'test.db'))
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def parsed_messages(session_id)
    @memory.load_messages(session_id).map { |m| JSON.parse(m['message']) }
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
    @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello' })
    @memory.save_message(session_id, { 'role' => 'assistant', 'content' => 'hi there' })

    messages = parsed_messages(session_id)
    assert_equal 2, messages.length
    assert_equal 'user', messages[0]['role']
    assert_equal 'hello', messages[0]['content']
    assert_equal 'assistant', messages[1]['role']
    assert_equal 'hi there', messages[1]['content']
  end

  def test_load_messages_returns_in_insertion_order
    session_id = @memory.create_session
    @memory.save_message(session_id, { 'role' => 'user', 'content' => 'first' })
    @memory.save_message(session_id, { 'role' => 'assistant', 'content' => 'second' })
    @memory.save_message(session_id, { 'role' => 'user', 'content' => 'third' })

    contents = parsed_messages(session_id).map { |m| m['content'] }
    assert_equal ['first', 'second', 'third'], contents
  end

  def test_load_messages_isolates_by_session
    session1 = @memory.create_session
    session2 = @memory.create_session
    @memory.save_message(session1, { 'role' => 'user', 'content' => 'session 1' })
    @memory.save_message(session2, { 'role' => 'user', 'content' => 'session 2' })

    messages = parsed_messages(session1)
    assert_equal 1, messages.length
    assert_equal 'session 1', messages[0]['content']
  end

  def test_load_messages_returns_empty_for_unknown_session
    assert_empty @memory.load_messages(999)
  end

  def test_list_sessions_returns_all_sessions
    @memory.create_session
    @memory.create_session
    assert_equal 2, @memory.list_sessions.length
  end

  def test_list_sessions_uses_first_user_message_as_preview
    session_id = @memory.create_session
    @memory.save_message(session_id, { 'role' => 'assistant', 'content' => 'ignored' })
    @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello world' })

    sessions = @memory.list_sessions
    assert_equal 'hello world', sessions.first['content']
  end

  def test_list_sessions_returns_empty_when_no_sessions
    assert_empty @memory.list_sessions
  end

  def test_timestamps_are_iso8601
    session_id = @memory.create_session
    @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello' })

    session = @memory.list_sessions.first
    message = @memory.load_messages(session_id).first

    assert_match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, session['started_at'])
    assert_match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, message['created_at'])
  end

  def test_save_message_returns_id
    session_id = @memory.create_session
    id = @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello' })
    assert_kind_of Integer, id
    assert id > 0
  end

  def test_save_tags_creates_tags
    session_id = @memory.create_session
    msg_id = @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello' })
    @memory.save_tags(msg_id, ['ruby', 'testing'])

    tags = @memory.list_tags.map { |t| t['name'] }
    assert_includes tags, 'ruby'
    assert_includes tags, 'testing'
  end

  def test_save_tags_downcases_names
    session_id = @memory.create_session
    msg_id = @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello' })
    @memory.save_tags(msg_id, ['Ruby', 'TESTING'])

    tags = @memory.list_tags.map { |t| t['name'] }
    assert_includes tags, 'ruby'
    assert_includes tags, 'testing'
    refute_includes tags, 'Ruby'
  end

  def test_save_tags_ignores_duplicates
    session_id = @memory.create_session
    msg_id = @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello' })
    @memory.save_tags(msg_id, ['ruby'])
    @memory.save_tags(msg_id, ['ruby'])

    assert_equal 1, @memory.list_tags.length
  end

  def test_find_messages_by_tag_returns_matching_messages
    session_id = @memory.create_session
    msg_id = @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello ruby' })
    @memory.save_tags(msg_id, ['ruby'])

    results = @memory.find_messages_by_tag('ruby')
    assert_equal 1, results.length
    assert_equal 'hello ruby', results.first['content']
  end

  def test_find_messages_by_tag_returns_empty_when_no_match
    assert_empty @memory.find_messages_by_tag('nonexistent')
  end

  def test_find_messages_by_tag_does_not_return_untagged_messages
    session_id = @memory.create_session
    msg_id = @memory.save_message(session_id, { 'role' => 'user', 'content' => 'about ruby' })
    other_id = @memory.save_message(session_id, { 'role' => 'user', 'content' => 'about python' })
    @memory.save_tags(msg_id, ['ruby'])
    @memory.save_tags(other_id, ['python'])

    results = @memory.find_messages_by_tag('ruby')
    assert_equal 1, results.length
    assert_equal 'about ruby', results.first['content']
  end

  def test_search_messages_by_query
    session_id = @memory.create_session
    @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello sqlite' })
    @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello ruby' })

    results = @memory.search_messages(query: 'sqlite')
    assert_equal 1, results.length
    assert_equal 'hello sqlite', results.first[:message]['content']
  end

  def test_search_messages_by_tag
    session_id = @memory.create_session
    msg_id = @memory.save_message(session_id, { 'role' => 'user', 'content' => 'about ruby' })
    @memory.save_tags(msg_id, ['ruby'])

    results = @memory.search_messages(tags: ['ruby'])
    assert_equal 1, results.length
    assert_equal 'about ruby', results.first[:message]['content']
  end

  def test_search_messages_respects_limit
    session_id = @memory.create_session
    5.times { |i| @memory.save_message(session_id, { 'role' => 'user', 'content' => "message #{i}" }) }

    results = @memory.search_messages(query: 'message', limit: 2)
    assert_equal 2, results.length
  end

  def test_search_messages_returns_session_id
    session_id = @memory.create_session
    @memory.save_message(session_id, { 'role' => 'user', 'content' => 'hello' })

    results = @memory.search_messages(query: 'hello')
    assert_equal session_id, results.first[:session_id]
  end
end
