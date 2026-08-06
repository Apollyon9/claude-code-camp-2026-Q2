module Boukensha
  # The core loop: call the API, check stop_reason, dispatch any tool calls
  # back through the registry, append results, repeat. Stops either when the
  # model returns a final text answer, or when max_iterations is reached, in
  # which case one last tools-disabled call asks the model to wrap up rather
  # than just cutting it off mid-thought.
  class Agent
    MAX_ITERATIONS = 25

    WRAP_UP_OUTPUT_TOKENS = 400
    WRAP_UP_DIRECTIVE = "You have reached your action limit for this turn. " \
      "Do not call any more tools. Briefly summarize what you accomplished " \
      "and what you were doing when you stopped."

    def initialize(context:, registry:, builder:, client:,
                   max_iterations: MAX_ITERATIONS, max_output_tokens: 1024)
      @context           = context
      @registry          = registry
      @builder           = builder
      @client            = client
      @max_iterations    = max_iterations
      @max_output_tokens = max_output_tokens
      @iteration         = 0
    end

    def run
      loop do
        return wrap_up if iteration_limit_reached?

        @iteration += 1
        response = @client.call(max_output_tokens: @max_output_tokens)
        parsed = @builder.parse_response(response)

        if parsed[:stop_reason] == "tool_use"
          handle_tool_calls(parsed[:content])
        else
          text = extract_text(parsed[:content])
          @context.messages << Message.new(:assistant, text)
          return text
        end
      end
    end

    private

    def iteration_limit_reached?
      @iteration >= @max_iterations
    end

    def extract_text(content)
      content.select { |b| b["type"] == "text" }.map { |b| b["text"] }.join
    end

    # The assistant turn is recorded as the full content array (including
    # the tool_use blocks), not just extracted text -- the next request has
    # to send the model's own tool call back to it, or the conversation
    # history won't make sense to the API on the following turn.
    def handle_tool_calls(content)
      @context.messages << Message.new(:assistant, content)

      content.select { |b| b["type"] == "tool_use" }.each do |block|
        result = dispatch_safely(block["name"], block["input"])
        @context.messages << Message.new(:tool_result, result.to_s, block["id"])
      end
    end

    # A tool raising (unknown name, bad args, whatever) becomes a normal
    # tool_result the model can see and react to, not a crashed turn.
    def dispatch_safely(name, args)
      @registry.dispatch(name, args)
    rescue StandardError => e
      "ERROR: #{e.class}: #{e.message}"
    end

    # Runs outside the counted loop: it never re-checks max_iterations, so
    # it cannot re-trigger itself, and tools are disabled so it can only
    # talk, not keep acting.
    def wrap_up
      @context.messages << Message.new(:user, WRAP_UP_DIRECTIVE)
      text = begin
        response = @client.call(max_output_tokens: WRAP_UP_OUTPUT_TOKENS, tools: [])
        parsed = @builder.parse_response(response)
        extracted = extract_text(parsed[:content])
        extracted.strip.empty? ? fallback_message : extracted
      rescue ApiError
        fallback_message
      end
      @context.messages << Message.new(:assistant, text)
      text
    end

    def fallback_message
      "I reached my #{@max_iterations}-action limit for this turn before finishing. " \
        "Ask me to continue and I'll pick up from here."
    end
  end
end
