# frozen_string_literal: true

require 'json'
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

  def save_message(session_id, message)
    @db.execute(
      'INSERT INTO messages (session_id, message, created_at) VALUES (?, ?, ?)',
      [session_id, JSON.generate(message), Time.now.iso8601]
    )
    @db.last_insert_row_id
  end

  def list_sessions
    @db.execute(<<~SQL)
      SELECT s.id, s.started_at, json_extract(m.message, '$.content') as content
      FROM sessions s
      LEFT JOIN messages m ON m.session_id = s.id AND json_extract(m.message, '$.role') = 'user'
      GROUP BY s.id
      ORDER BY s.started_at DESC
    SQL
  end

  def load_messages(session_id)
    @db.execute('SELECT message, created_at FROM messages WHERE session_id = ? ORDER BY created_at ASC',
                session_id.to_i)
  end

  def save_tags(message_id, tags)
    tags.each do |tag|
      @db.execute('INSERT OR IGNORE INTO tags (name, created_at) VALUES (?, ?)', [tag.downcase, Time.now.iso8601])
      tag_id = @db.execute('SELECT id FROM tags WHERE name = ?', tag.downcase).first['id']
      @db.execute('INSERT OR IGNORE INTO message_tags (message_id, tag_id) VALUES (?, ?)', [message_id, tag_id])
    end
  end

  def find_messages_by_tag(tag)
    messages = @db.execute(<<~SQL, tag)
      SELECT m.message FROM messages m
      JOIN message_tags mt ON mt.message_id = m.id
      JOIN tags t ON t.id = mt.tag_id
      WHERE t.name = ?
    SQL
    messages.map { |m| JSON.parse(m['message']) }
  end

  def list_tags
    @db.execute('SELECT id, name, created_at FROM tags ORDER BY name')
  end

  def search_messages(tags: [], query: nil, limit: 5)
    sql = <<~SQL
      SELECT DISTINCT m.id, m.message, m.created_at, s.id as session_id
      FROM messages m
      JOIN sessions s ON s.id = m.session_id
    SQL
    params = []

    if tags.any?
      placeholders = tags.map { '?' }.join(', ')
      sql += %[
        JOIN message_tags mt ON mt.message_id = m.id
        JOIN tags t ON t.id = mt.tag_id
        WHERE t.name IN (#{placeholders})
      ]
      params.concat(tags.map(&:downcase))
    end

    if query
      clause = "json_extract(m.message, '$.content') LIKE ?"
      sql += tags.any? ? " AND #{clause}" : " WHERE #{clause}"
      params << "%#{query}%"
    end

    sql += 'ORDER BY m.created_at DESC LIMIT ?'
    params << limit

    @db.execute(sql, params).map do |row| 
      {
        message: JSON.parse(row['message']),
        created_at: row['created_at'],
        session_id: row['session_id']
      }
    end
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
        message TEXT,
        created_at DATETIME NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      )
    SQL

    @db.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        created_at DATETIME NOT NULL 
      )
    SQL

    @db.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS message_tags (
        message_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (message_id, tag_id),
        FOREIGN KEY (message_id) REFERENCES messages(id),
        FOREIGN KEY (tag_id) REFERENCES tags(id)
      )
    SQL
  end
end
