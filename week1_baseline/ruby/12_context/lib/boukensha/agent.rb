module Boukensha
  # The core loop: call the API, check stop_reason, dispatch any tool calls
  # back through the registry, append results, repeat. Stops on whichever
  # circuit breaker trips first -- max_iterations (tool-call count) or
  # max_turn_tokens (cumulative input+output spend this turn) -- at which
  # point one last tools-disabled call asks the model to wrap up rather than
  # just cutting it off mid-thought. Compacts Context before the turn starts
  # if usage is already past its threshold.
  class Agent
    MAX_ITERATIONS = 25

    WRAP_UP_OUTPUT_TOKENS = 400
    WRAP_UP_DIRECTIVE = "You have reached your action limit for this turn. " \
      "Do not call any more tools. Briefly summarize what you accomplished " \
      "and what you were doing when you stopped."

    def initialize(context:, registry:, builder:, client:, logger: NullLogger.new,
                   max_iterations: MAX_ITERATIONS, max_turn_tokens: nil, max_output_tokens: 1024)
      @context           = context
      @registry          = registry
      @builder           = builder
      @client            = client
      @logger            = logger
      @max_iterations    = max_iterations
      @max_turn_tokens    = max_turn_tokens.to_i # 0/nil = disabled
      @max_output_tokens = max_output_tokens
      @iteration         = 0
    end

    def run
      @iteration = 0
      @context.reset_turn_tokens
      compact_if_needed

      loop do
        if iteration_limit_reached?
          @logger.limit_reached(kind: "max_iterations", n: @iteration, max: @max_iterations)
          return wrap_up("max_iterations")
        end
        if token_limit_reached?
          @logger.limit_reached(kind: "max_turn_tokens", n: @context.turn_tokens, max: @max_turn_tokens)
          return wrap_up("max_turn_tokens")
        end

        @iteration += 1
        @logger.iteration(n: @iteration, max: @max_iterations)

        response = @client.call(max_output_tokens: @max_output_tokens)
        cost = record_usage(response)
        parsed = @builder.parse_response(response)

        if parsed[:stop_reason] == "tool_use"
          calls = parsed[:content].count { |b| b["type"] == "tool_use" }
          @logger.response(text: "(tool use -- #{calls} call#{'s' unless calls == 1})", stop_reason: "tool_use", cost: cost)
          handle_tool_calls(parsed[:content])
        else
          text = extract_text(parsed[:content])
          @logger.response(text: text, stop_reason: parsed[:stop_reason], cost: cost)
          @logger.turn_end(reason: "completed", iterations: @iteration, tokens: @context.turn_tokens)
          @context.messages << Message.new(:assistant, text)
          return text
        end
      end
    end

    private

    def iteration_limit_reached?
      @iteration >= @max_iterations
    end

    def token_limit_reached?
      @max_turn_tokens.positive? && @context.turn_tokens >= @max_turn_tokens
    end

    # Reads usage from the raw response, not the normalized parse_response
    # shape -- usage accounting is provider-specific bookkeeping, not part
    # of the {stop_reason:, content:} contract every backend normalizes to.
    # Anthropic's raw response always carries a top-level "usage" object
    # regardless of stop_reason, single-backend for now so this stays a
    # direct read rather than a new field threaded through every backend.
    # Returns this call's estimated USD cost so the caller can log it --
    # Backends::Base#estimate_cost already existed with real pricing tables,
    # it just had no caller until now.
    def record_usage(response)
      usage = response["usage"] || {}
      input_tokens  = usage["input_tokens"].to_i
      output_tokens = usage["output_tokens"].to_i
      @context.add_turn_tokens(input_tokens, output_tokens)
      @context.update_tokens(input_tokens)
      @builder.backend.estimate_cost(input_tokens: input_tokens, output_tokens: output_tokens)
    end

    def compact_if_needed
      return unless @context.needs_compaction?

      before  = @context.current_tokens
      dropped = @context.compact_messages!
      @logger.compaction(before: before, dropped: dropped, context_window: @context.context_window)
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

    # Runs outside the counted loop: it never re-checks either limit, so it
    # cannot re-trigger itself, and tools are disabled so it can only talk,
    # not keep acting.
    def wrap_up(reason)
      @context.messages << Message.new(:user, WRAP_UP_DIRECTIVE)
      cost = nil
      text = begin
        response = @client.call(max_output_tokens: WRAP_UP_OUTPUT_TOKENS, tools: [])
        cost = record_usage(response)
        parsed = @builder.parse_response(response)
        extracted = extract_text(parsed[:content])
        extracted.strip.empty? ? fallback_message(reason) : extracted
      rescue ApiError
        fallback_message(reason)
      end
      @logger.response(text: text, stop_reason: "wrap_up", cost: cost)
      @logger.turn_end(reason: reason, iterations: @iteration, tokens: @context.turn_tokens)
      @context.messages << Message.new(:assistant, text)
      text
    end

    def fallback_message(reason)
      "I reached my #{reason == 'max_turn_tokens' ? 'token' : 'action'} limit for this turn before " \
        "finishing (#{reason}). Ask me to continue and I'll pick up from here."
    end
  end
end
