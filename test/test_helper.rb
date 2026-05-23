# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/reporters'
require 'tmpdir'
require 'tempfile'
require 'fileutils'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'tool'
require 'permissions'
require 'path_guard'
require 'context_manager'
require 'tools/read_file'
require 'tools/list_dir'
require 'tools/write_file'
require 'tools/edit_file'
require 'tools/run_command'

Minitest::Reporters.use!([Minitest::Reporters::DefaultReporter.new(color: true)])
