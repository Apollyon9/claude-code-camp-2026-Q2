module Boukensha
  # Assembles a backend-agnostic request from Context (conversation state)
  # and Registry (tool state), and hands the actual schema work off to the
  # backend. Neither Context nor Registry knows a backend exists; this is
  # the one place that reaches into both.
  class PromptBuilder
    attr_reader :backend

    def initialize(context, registry, backend)
      @context  = context
      @registry = registry
      @backend  = backend
    end

    def to_messages
      @backend.to_messages(@context.messages)
    end

    def to_tools
      @backend.to_tools(@registry.tools)
    end

    # tools: lets a caller override the registered tool set for one call
    # (e.g. a later wind-down call that disables tool use entirely).
    def to_api_payload(max_output_tokens: 1024, tools: nil)
      @backend.to_payload(
        system: @context.system,
        messages: to_messages,
        tools: tools || to_tools,
        max_output_tokens: max_output_tokens
      )
    end

    def parse_response(response)
      @backend.parse_response(response)
    end

    def headers
      @backend.headers
    end

    def url
      @backend.url
    end
  end
end
