# frozen_string_literal: true

require_relative 'test_helper'
require 'setup'
require 'stringio'

class SetupTest < Minitest::Test
  def teardown
    $stdin = STDIN
  end

  # Temporarily replaces a singleton method and restores it after the block.
  # Pass the fake implementation as a lambda, and the test code as a block.
  def stub_method(object, method_name, implementation, &block)
    original = object.method(method_name)
    object.define_singleton_method(method_name, &implementation)
    block.call
  ensure
    object.define_singleton_method(method_name, &original)
  end

  def test_fetch_models_returns_model_ids
    fake_body = JSON.generate({ 'data' => [{ 'id' => 'model-a' }, { 'id' => 'model-b' }] })
    fake_response = Struct.new(:body).new(fake_body)
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:request) { |_| fake_response }

    stub_method(Net::HTTP, :new, ->(*_) { fake_http }) do
      result = Setup.send(:fetch_models, 'https://example.com/v1')
      assert_equal ['model-a', 'model-b'], result
    end
  end

  def test_run_saves_correct_config
    $stdin = StringIO.new("1\n1\n")
    written_config = nil

    stub_method(Setup, :fetch_models, ->(_) { ['deepseek-v4-flash', 'deepseek-v3'] }) do
      stub_method(Config, :read_config, -> { {} }) do
        stub_method(Config, :update_config, ->(config) { written_config = config }) do
          capture_io { Setup.run }
        end
      end
    end

    assert_equal 'go', written_config['plan']
    assert_equal 'deepseek-v4-flash', written_config['model']
    assert_equal 'https://opencode.ai/zen/go/v1', written_config['base_url']
  end

  def test_run_preserves_existing_config_keys
    $stdin = StringIO.new("1\n1\n")
    written_config = nil
    existing = { 'permissions' => { 'allowed' => ['git status'] } }

    stub_method(Setup, :fetch_models, ->(_) { ['deepseek-v4-flash'] }) do
      stub_method(Config, :read_config, -> { existing }) do
        stub_method(Config, :update_config, ->(config) { written_config = config }) do
          capture_io { Setup.run }
        end
      end
    end

    assert_equal({ 'allowed' => ['git status'] }, written_config['permissions'])
  end

  def test_run_raises_on_invalid_plan
    $stdin = StringIO.new("99\n")

    assert_raises(RuntimeError) do
      capture_io { Setup.run }
    end
  end

  def test_run_raises_on_invalid_model
    $stdin = StringIO.new("1\n99\n")

    stub_method(Setup, :fetch_models, ->(_) { ['deepseek-v4-flash'] }) do
      stub_method(Config, :read_config, -> { {} }) do
        assert_raises(RuntimeError) do
          capture_io { Setup.run }
        end
      end
    end
  end
end
