require_relative "base"

# https://platform.claude.com/docs/en/api/beta/messages/create
module Boukensha
  module Backends
    class Anthropic < Base
      BASE_URL = "https://api.anthropic.com/v1/messages"

      MODELS = {
        "claude-haiku-4-5" => {
          context_window: 200_000,
          cost_per_million: { input: 1.0, output: 5.0 }
        },
        "claude-sonnet-4-6" => {
          context_window: 1_000_000,
          cost_per_million: { input: 3.0, output: 15.0 }
        },
        "claude-opus-4-8" => {
          context_window: 1_000_000,
          cost_per_million: { input: 5.0, output: 25.0 }
        }
      }.freeze

      def initialize(api_key:, model:)
        @api_key = api_key
        configure_model(model)
      end

      # Anthropic wraps a tool result in a *user* message, not a dedicated
      # role, even though it's Boukensha reporting the result, not the human.
      def to_messages(messages)
        messages.map do |msg|
          case msg.role
          when :tool_result
            {
              role: "user",
              content: [{ type: "tool_result", tool_use_id: msg.tool_use_id, content: msg.content }]
            }
          else
            { role: msg.role.to_s, content: msg.content }
          end
        end
      end

      def to_tools(tools)
        tools.values.map do |tool|
          {
            name: tool.name,
            description: tool.description,
            input_schema: {
              type: "object",
              properties: tool.parameters,
              required: tool.parameters.keys.map(&:to_s)
            }
          }
        end
      end

      def to_payload(system:, messages:, tools:, max_output_tokens: 1024)
        {
          model: model,
          system: system,
          max_tokens: max_output_tokens,
          tools: tools,
          messages: messages
        }
      end

      def headers
        {
          "Content-Type"      => "application/json",
          "x-api-key"         => @api_key,
          "anthropic-version" => "2023-06-01"
        }
      end

      def url
        BASE_URL
      end

      # Normalizes an Anthropic response to { stop_reason:, content: }, the
      # shape every backend returns so Agent never branches on provider.
      def parse_response(response)
        stop_reason = response["stop_reason"] == "tool_use" ? "tool_use" : "end_turn"
        { stop_reason: stop_reason, content: response["content"] || [] }
      end
    end
  end
end
