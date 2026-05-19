# frozen_string_literal: true

require_relative 'test_helper'
require 'session_manager'
require 'stringio'

class FakeMemoryForSession
  def initialize(sessions = [], messages = [])
    @sessions = sessions
    @messages = messages
  end

  def list_sessions = @sessions

  def load_messages(_session_id)
    @messages.map { |msg| { 'message' => JSON.generate(msg) } }
  end
end

class FakeContextForSession
  attr_reader :added_messages, :persist_flags

  def initialize
    @added_messages = []
    @persist_flags = []
  end

  def add(message, persist: true)
    @added_messages << message
    @persist_flags << persist
  end
end

class SessionManagerTest < Minitest::Test
  def teardown
    $stdin = STDIN
  end

  def test_sessions_menu_returns_nil_when_no_sessions
    memory = FakeMemoryForSession.new([])
    result = nil
    capture_io { result = SessionManager.sessions_menu(memory) }
    assert_nil result
  end

  def test_sessions_menu_returns_selected_session_id
    sessions = [{ 'id' => 1, 'content' => 'hello', 'started_at' => '2026-01-01' }]
    memory = FakeMemoryForSession.new(sessions)
    $stdin = StringIO.new("1\n")
    result = nil
    capture_io { result = SessionManager.sessions_menu(memory) }
    assert_equal 1, result
  end

  def test_sessions_menu_raises_on_invalid_session_id
    sessions = [{ 'id' => 1, 'content' => 'hello', 'started_at' => '2026-01-01' }]
    memory = FakeMemoryForSession.new(sessions)
    $stdin = StringIO.new("99\n")
    assert_raises(RuntimeError) do
      capture_io { SessionManager.sessions_menu(memory) }
    end
  end

  def test_load_messages_adds_each_message_to_context
    messages = [{ 'role' => 'user', 'content' => 'hello' }, { 'role' => 'assistant', 'content' => 'hi' }]
    memory = FakeMemoryForSession.new([], messages)
    context = FakeContextForSession.new

    SessionManager.load_messages(memory, context, 1)

    assert_equal 2, context.added_messages.length
  end

  def test_load_messages_adds_without_persisting
    messages = [{ 'role' => 'user', 'content' => 'hello' }]
    memory = FakeMemoryForSession.new([], messages)
    context = FakeContextForSession.new

    SessionManager.load_messages(memory, context, 1)

    assert_equal [false], context.persist_flags
  end

  def test_load_messages_does_nothing_when_session_id_is_nil
    memory = FakeMemoryForSession.new
    context = FakeContextForSession.new
    capture_io { SessionManager.load_messages(memory, context, nil) }
    assert_empty context.added_messages
  end
end
