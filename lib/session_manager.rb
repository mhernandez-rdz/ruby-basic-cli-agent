# frozen_string_literal: true

require 'json'

module SessionManager # :nodoc:
  class << self
    def sessions_menu(memory) # rubocop:disable Metrics/AbcSize
      sessions = memory.list_sessions
      if sessions.empty?
        puts "No previous sessions stored yet\n"
        return
      end
      sessions.each { |session| puts "[#{session['id']}]: #{session['content']}-#{session['started_at']}" }
      puts 'Select your session:'
      session_id = $stdin.gets&.chomp&.to_i
      raise 'Session id must exist' unless sessions.map { |s| s['id'] }.include?(session_id)

      session_id
    end

    def load_messages(memory, context, session_id)
      if session_id.nil?
        puts "You must select a session id to continue\n"
        return
      end

      messages = memory.load_messages(session_id)
      messages.each { |msg| context.add(JSON.parse(msg['message']), persist: false) }
    end
  end
end
