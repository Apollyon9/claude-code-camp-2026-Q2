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

    def initialize(context:, registry:, builder:, client:, logger: NullLogger.new,
                   max_iterations: MAX_ITERATIONS, max_output_tokens: 1024)
      @context           = context
      @registry          = registry
      @builder           = builder
      @client            = client
      @logger            = logger
      @max_iterations    = max_iterations
      @max_output_tokens = max_output_tokens
      @iteration         = 0
    end

    # Resets the iteration count at the start of every call. Agent is meant
    # to be reused across multiple turns (see Repl, step 08) rather than
    # rebuilt per turn, so each #run gets its own fresh budget -- without
    # this, a long REPL session would accumulate iterations across turns and
    # hit the ceiling on a turn that just started.
    def run
      @iteration = 0

      loop do
        if iteration_limit_reached?
          @logger.limit_reached(kind: "max_iterations", n: @iteration, max: @max_iterations)
          return wrap_up
        end

        @iteration += 1
        @logger.iteration(n: @iteration, max: @max_iterations)

        response = @client.call(max_output_tokens: @max_output_tokens)
        parsed = @builder.parse_response(response)

        if parsed[:stop_reason] == "tool_use"
          calls = parsed[:content].count { |b| b["type"] == "tool_use" }
          @logger.response(text: "(tool use -- #{calls} call#{'s' unless calls == 1})", stop_reason: "tool_use")
          handle_tool_calls(parsed[:content])
        else
          text = extract_text(parsed[:content])
          @logger.response(text: text, stop_reason: parsed[:stop_reason])
          @logger.turn_end(reason: "completed", iterations: @iteration)
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
        name = block["name"]
        args = block["input"]
        @logger.tool_call(name: name, args: args)

        begin
          result = @registry.dispatch(name, args)
          @logger.tool_result(name: name, result: result, ok: true)
        rescue StandardError => e
          result = "ERROR: #{e.class}: #{e.message}"
          @logger.tool_result(name: name, result: result, ok: false, error: e.message)
        end

        @context.messages << Message.new(:tool_result, result.to_s, block["id"])
      end
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
      @logger.response(text: text, stop_reason: "wrap_up")
      @logger.turn_end(reason: "max_iterations", iterations: @iteration)
      @context.messages << Message.new(:assistant, text)
      text
    end

    def fallback_message
      "I reached my #{@max_iterations}-action limit for this turn before finishing. " \
        "Ask me to continue and I'll pick up from here."
    end
  end
end
