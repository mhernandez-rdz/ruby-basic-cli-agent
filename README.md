# ruby-basic-cli-agent

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

Built-in tools: `read_file`, `list_dir`, `write_file`, `edit_file`, `run_command`.

## Security

The agent includes two safety layers configurable via `.agent.yml`:

**Command permissions** — all `run_command` calls require user confirmation unless explicitly allowed. Only exact command matches are permitted:

```yaml
permissions:
  allowed:
    - "git status"
    - "git diff"
    - "pwd"
```

**Path guard** — file tools (`read_file`, `list_dir`, `write_file`, `edit_file`) are restricted to the working directory by default. Additional directories can be whitelisted:

```yaml
paths:
  allowed:
    - "."
    - "/home/user/Documents/Notes"
```

**Sandbox** — if `firejail` is installed, the agent automatically runs inside it on startup, restricting filesystem access at the OS level.

## Configuration

The system prompt can be customized by creating `.agent_prompt.txt` in the working directory. If the file exists, it takes priority over the default prompt.

## Installation

```bash
gem install bundler
bundle install
```

## Setup

Before running the agent for the first time, configure the plan and model:

```bash
bin/run --setup
```

This will prompt you to select an OpenCode plan and a model, and save the configuration to `.agent.yml`.

You also need to export your API key:

```bash
export OPENCODE_API_KEY=your_key_here
```

## Usage

**Start a new chat session:**
```bash
bin/run
```

**Resume a specific session by ID:**
```bash
bin/run --session 42
```

**List previous sessions and choose one interactively:**
```bash
bin/run --session
```

Type an empty line or press `Ctrl+D` to exit the chat.

## Running tests

```bash
bundle exec ruby -Ilib -Itest test/<file>_test.rb
```

## Structure

```
bin/run               # entry point and main loop
lib/
  client.rb           # HTTP client for the LLM API
  context_manager.rb  # conversation history and compaction
  memory.rb           # SQLite persistence for sessions and messages
  session_manager.rb  # session listing and recovery
  setup.rb            # first-time configuration wizard
  tool.rb             # base class and tool registry
  tool_executor.rb    # tool dispatch, permissions and path guard
  permissions.rb      # command allowlist
  path_guard.rb       # filesystem access control
  tools/              # built-in tool implementations
  utils/
    config.rb         # system prompt and config loader
storage/
  memory.db           # SQLite database (auto-created)
test/                 # minitest suite
.agent.yml            # permissions, paths, and model configuration
```

## License

MIT License — see [LICENSE](LICENSE).
