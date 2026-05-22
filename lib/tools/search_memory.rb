# frozen_string_literal: true

class SearchMemory < Tool # :nodoc:
  def call(args)
    memory = Memory.new
    tags = args['tags'] || []
    query = args['query']
    limit = args['limit'] || 5

    result = memory.search_messages(tags:, query:, limit:)

    if result.empty?
      return 'No relevant memories found.'
    end

    result.each_with_index.map do |r, i| 
      msg = r[:message]
      "[#{i + 1}] (#{r[:created_at]}, session #{r[:session_id]}) #{msg['role']}: #{msg['content']}"
    end.join("\n")
  end

  class << self
    def tool_name
      'search_memory'
    end

    def schema
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Search past conversations for relevant information using tags or keywords',
          parameters: {
            type: 'object',
            properties: {
              tags: {
                type: 'array',
                items: { type: 'string' },
                description: 'Tags to filter by (e.g. ["python", "bug"])'
              },
              query: {
                type: 'string',
                description: 'Free-text search in message content'
              },
              limit: {
                type: 'integer',
                description: 'Maximum number of results',
                default: 5
              }
            },
            anyOf: [
              { required: ['tags'] },
              { required: ['query'] }
            ]
          }
        }
      }
    end
  end
end
