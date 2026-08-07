require_relative "test_helper"

class TestBackendsBase < Minitest::Test
  # Anonymous subclass, just enough to exercise Base's own logic without
  # depending on a real provider's schema.
  def dummy_backend_class
    klass = Class.new(Boukensha::Backends::Base) do
      def initialize(model:)
        configure_model(model)
      end
    end
    klass.const_set(:MODELS, {
      "fake-model" => { context_window: 1000, cost_per_million: { input: 1.0, output: 2.0 } }
    }.freeze)
    klass
  end

  def test_models_raises_without_a_models_constant
    klass = Class.new(Boukensha::Backends::Base)
    assert_raises(NotImplementedError) { klass.models }
  end

  def test_validate_model_accepts_known_model
    backend = dummy_backend_class.new(model: "fake-model")
    assert_equal "fake-model", backend.model
  end

  def test_validate_model_rejects_unknown_model
    assert_raises(Boukensha::UnsupportedModelError) { dummy_backend_class.new(model: "not-a-real-model") }
  end

  def test_context_window_reads_from_models_table
    backend = dummy_backend_class.new(model: "fake-model")
    assert_equal 1000, backend.context_window
  end

  def test_estimate_cost
    backend = dummy_backend_class.new(model: "fake-model")
    # 1000 input tokens @ $1/M + 1000 output tokens @ $2/M = 0.001 + 0.002
    assert_in_delta 0.003, backend.estimate_cost(input_tokens: 1000, output_tokens: 1000), 0.0001
  end
end
