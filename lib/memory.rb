# frozen_string_literal: true

require 'sqlite3'
require 'time'

class Memory # :nodoc:
  DB_PATH = File.expand_path('../storage/memory.db', __dir__)

  def initialize(path = DB_PATH)
    Dir.mkdir(File.dirname(path)) unless Dir.exist?(File.dirname(path))
    @db = SQLite3::Database.new(path)
    @db.results_as_hash = true
    setup_schema
  end

  def create_session
    @db.execute('INSERT INTO sessions (started_at) VALUES (?)', Time.now.iso8601)
    @db.last_insert_row_id
  end

  def save_message(session_id, role, content)
    @db.execute(
      'INSERT INTO messages (session_id, role, content, created_at) VALUES (?, ?, ?, ?)',
      [session_id, role, content, Time.now.iso8601]
    )
  end

  def list_sessions
    @db.execute(<<~SQL)
      SELECT s.id, s.started_at, m.content
      FROM sessions s
      LEFT JOIN messages m ON m.session_id = s.id AND m.role = 'user'
      GROUP BY s.id
      ORDER BY s.started_at DESC
    SQL
  end

  def load_messages(session_id)
    @db.execute('SELECT role, content, created_at FROM messages WHERE session_id = ? ORDER BY created_at ASC', session_id.to_i)
  end

  private

  def setup_schema # rubocop:disable Metrics/MethodLength
    @db.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at DATETIME NOT NULL
      )
    SQL

    @db.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT,
        created_at DATETIME NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      )
    SQL
  end
end
