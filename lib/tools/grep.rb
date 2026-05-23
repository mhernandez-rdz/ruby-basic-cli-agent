# frozen_string_literal: true

class Grep < Tool # :nodoc:
  RG_CMD = 'rg --line-number --no-heading'
  GREP_CMD = 'grep -rn'

  def call(args)
    cmd = handle_command(args)
    stdout, stderr, status = Open3.capture3(cmd)
    return 'No matches found' if stdout.empty? && status.success?

    return stderr if stdout.empty?

    all_lines = stdout.lines
    lines = all_lines.first(50).join
    lines += "\n... (results truncated)" if all_lines.count > 50
    lines
  end

  class << self
    def tool_name
      'grep'
    end

    def schema # rubocop:disable Metrics/MethodLength
      {
        type: 'function',
        function: {
          name: tool_name,
          description: 'Search file contents with a regex pattern using ripgrep. Supports filtering by file type.',
          parameters: {
            type: 'object',
            properties: {
              pattern: { type: 'string', description: 'Regex pattern to search for' },
              path: { type: 'string', description: 'Directory or file to search in (default: current dir)' },
              include: { type: 'string', description: 'File extension filter, e.g. "rb", "js", "md"' }
            },
            required: ['pattern']
          }
        }
      }
    end
  end

  private

  def handle_command(args)
    pattern = args['pattern']
    path    = args['path'] || '.'
    include = args['include']

    cmd = searcher.dup
    cmd << " -g '*.#{Shellwords.escape(include)}'" if include && rg?
    cmd << " --include='*.#{Shellwords.escape(include)}'" if include && !rg?
    cmd << " #{Shellwords.escape(pattern)} #{Shellwords.escape(path)}"
  end

  def searcher
    rg? ? RG_CMD : GREP_CMD
  end

  def rg?
    system('which rg > /dev/null 2>&1')
  end
end
