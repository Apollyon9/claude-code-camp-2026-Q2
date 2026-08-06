require_relative "test_helper"

# Boukensha.run always builds a real Client bound to the real Anthropic URL --
# there's no seam to fake the network at this level without bolting one onto
# the public API purely for testability. So only the setup paths that raise
# *before* Agent#run would make a real call are covered here; the actual
# request/response wiring is already proven by Client, Agent, and
# PromptBuilder's own tests, plus a live run in examples/example.rb.
class TestBoukenshaRun < Minitest::Test
  include ConfigTestHelper

  def test_raises_config_error_when_no_model_configured
    with_config_dir(settings_yaml: "tasks:\n  player:\n    provider: anthropic\n") do
      error = assert_raises(Boukensha::ConfigError) { Boukensha.run(task: "hi") }
      assert_match(/no model configured/, error.message)
    end
  end

  def test_raises_for_an_unsupported_backend
    with_config_dir(settings_yaml: "tasks:\n  player:\n    provider: anthropic\n    model: claude-haiku-4-5\n") do
      error = assert_raises(ArgumentError) { Boukensha.run(task: "hi", backend: :openai) }
      assert_match(/openai/, error.message)
    end
  end

  def test_model_and_system_overrides_avoid_needing_settings_at_all
    with_config_dir(settings_yaml: "tasks: {}\n") do
      error = assert_raises(ArgumentError) do
        Boukensha.run(task: "hi", model: "claude-haiku-4-5", system: "s", backend: :openai)
      end
      assert_match(/openai/, error.message)
    end
  end
end
