# llm_harnes

A Ruby implementation of the core concepts described in Mihail Eric's article [*The Emperor Has No Clothes: How to Code Claude Code in 200 Lines of Code*](https://www.mihaileric.com/The-Emperor-Has-No-Clothes/).

## Motivation

The article argues that AI coding assistants like Claude Code, despite appearing magical, are built on a straightforward architectural pattern: a loop where a language model requests tool executions, the host program runs them locally, and the results are fed back to the model.

This project replicates that idea in Ruby, using plain `net/http` and no AI-specific libraries, to demonstrate that the core loop is accessible and understandable.

## How it works

The system runs a conversation loop with a language model (DeepSeek via [OpenCode Go](https://opencode.ai/docs/es/go)):

1. User sends a message
2. The model decides whether to respond directly or invoke a tool
3. If a tool is invoked, the program executes it locally and returns the result to the model
4. The model formulates a final response based on the tool output

```
user message
     ↓
   model
     ↓
 tool_calls?  →  yes  →  execute tool  →  back to model
     ↓ no
 final response
```

## Tools

Built-in tools live in `lib/tools/`. The system auto-discovers any class that inherits from `Tool`, so extending the toolset is as simple as adding a new file:

```ruby
class MyTool < Tool
  def self.tool_name = "my_tool"

  def self.schema
    {
      type: "function",
      function: {
        name: tool_name,
        description: "Does something useful",
        parameters: {
          type: "object",
          properties: {
            input: { type: "string", description: "Some input" }
          },
          required: ["input"]
        }
      }
    }
  end

  def call(args)
    # actual implementation
  end
end
```

Built-in tools: `read_file`, `list_dir`, `write_file`.

## Structure

```
bin/run          # entry point and main loop
lib/
  client.rb      # HTTP client for the LLM API
  tool.rb        # base class and tool registry
  tools/         # built-in tool implementations
```

## License

MIT License — see [LICENSE](LICENSE).
