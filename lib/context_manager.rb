# frozen_string_literal: true

class ContextManager # :nodoc:
  THRESHOLD = 20
  KEEP_RECENT = 5
  SUMMARIZE_MESSAGE = 'You are an assistant that summarizes conversations concisely, preserving key decisions, '\
                      'context and facts.'

  attr_reader :messages

  def initialize(client, system_prompt:)
    @client = client
    @messages = [{ 'role' => 'system', 'content' => system_prompt }]
  end

  def add(message)
    messages << normalize(message)
  end

  def add_user_message(message)
    messages << normalize(message)
    compact! if needs_compaction?
  end

  private

  def normalize(message)
    message.transform_keys(&:to_s)
  end

  def needs_compaction?
    conversation_messages.length > THRESHOLD
  end

  def compact!
    to_summarize = conversation_messages[...-KEEP_RECENT]
    recent       = conversation_messages.last(KEEP_RECENT)
    summary      = summarize(to_summarize)
    @messages    = [@messages.first,
                    { 'role' => 'assistant', 'content' => "Previous conversation summary: #{summary}" },
                    *recent]
  end

  def summarize(messages_to_summarize)
    summary_messages = [
      { role: 'system', content: SUMMARIZE_MESSAGE },
      { role: 'user', content: format_messages(messages_to_summarize) }
    ]
    @client.chat(summary_messages)
  end

  def conversation_messages
    @messages[1..]
  end

  def format_messages(messages)
    messages.reject { |m| m['content'].nil? || m['content'].empty? }
            .map { |m| "#{m['role']}: #{m['content']}" }.join("\n")
  end
end
