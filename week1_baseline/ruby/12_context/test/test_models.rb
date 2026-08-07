require_relative "test_helper"

class TestModels < Minitest::Test
  def test_known_model_returns_its_context_window
    assert_equal 200_000, Boukensha::Models.context_window("claude-haiku-4-5")
    assert_equal 1_000_000, Boukensha::Models.context_window("claude-sonnet-4-6")
  end

  def test_unknown_model_falls_back_to_default
    assert_equal Boukensha::Models::DEFAULT_CONTEXT_WINDOW, Boukensha::Models.context_window("not-a-real-model")
  end

  def test_accepts_a_symbol
    assert_equal 200_000, Boukensha::Models.context_window(:"claude-haiku-4-5")
  end
end
