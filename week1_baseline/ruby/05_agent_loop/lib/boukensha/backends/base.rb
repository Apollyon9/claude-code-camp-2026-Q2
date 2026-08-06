require_relative "../errors"

module Boukensha
  module Backends
    # Common base for provider backends. A backend knows one provider's exact
    # request/response schema and exposes it through the same interface, so
    # PromptBuilder and (later) Agent never need to know which provider
    # they're talking to.
    #
    # Every backend must:
    #   - define a MODELS constant: { "model-id" => { context_window:, cost_per_million: { input:, output: } } }
    #   - implement #to_messages, #to_tools, #to_payload, #parse_response, #headers, #url
    class Base
      attr_reader :model

      def self.models
        const_get(:MODELS)
      rescue NameError
        raise NotImplementedError, "#{self} must define MODELS"
      end

      def self.model_info(model)
        models[model.to_s]
      end

      def self.validate_model!(model)
        model = model.to_s
        return model if model_info(model)

        supported = models.keys.sort.join(", ")
        raise UnsupportedModelError, "#{name} does not support model #{model.inspect}. Supported models: #{supported}"
      end

      def context_window
        model_info.fetch(:context_window)
      end

      def estimate_cost(input_tokens:, output_tokens:)
        costs = model_info.fetch(:cost_per_million)
        ((input_tokens * costs.fetch(:input)) + (output_tokens * costs.fetch(:output))) / 1_000_000.0
      end

      private

      attr_reader :model_info

      def configure_model(model)
        @model      = self.class.validate_model!(model)
        @model_info = self.class.model_info(@model)
      end
    end
  end
end
