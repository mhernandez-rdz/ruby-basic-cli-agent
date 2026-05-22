# frozen_string_literal: true

class Tagger # :nodoc:
  PROMPT = 'You are a tagging assistant. Given a message, return a JSON array of 1-3 short lowercase tags. ' \
           'Reuse existing tags when possible. Return ONLY the JSON array, nothing else.'

  def initialize(client, memory)
    @client = client
    @memory = memory
  end

  def tag_async(message_id, content)
    Thread.new { tag(message_id, content) }
  end

  private

  def tag(message_id, content)
    existing = @memory.list_tags.map { |t| t['name'] }.join(', ')
    messages = [
      { role: 'system', content: PROMPT },
      { role: 'user', content: "Existing tags: #{existing}\n Message: #{content}" }
    ]
    raw = @client.chat(messages)
    tags = JSON.parse(raw)
    @memory.save_tags(message_id, tags)
  rescue StandardError => _e
    # tagging es best-effort, never should interrumpt chat
  end
end
