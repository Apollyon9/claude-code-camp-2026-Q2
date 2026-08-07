require_relative "message"

module Boukensha
  # Everything the agent knows for the current turn: the system prompt, the
  # full conversation history, and how much of the model's context window
  # is actually in use. Tool storage lives on Registry, not here.
  #
  # A real class, not a Struct like earlier steps -- once there's behaviour
  # beyond holding fields (compaction, token accounting), a Struct with a
  # dozen methods bolted onto its block stops being the right shape.
  class Context
    attr_reader :system, :messages, :context_window, :working_dir,
                :turn_tokens, :compaction_threshold
    attr_accessor :current_tokens

    def initialize(system:, context_window: 200_000, working_dir: nil, compaction_threshold: 0.85)
      @system               = system
      @context_window       = context_window
      @working_dir          = working_dir
      @compaction_threshold = compaction_threshold
      @messages             = []
      @current_tokens       = 0
      @turn_tokens          = 0
    end

    # Reset the cumulative per-turn spend counter. Called at the start of a
    # turn (Agent#run), not per-message.
    def reset_turn_tokens
      @turn_tokens = 0
    end

    # Add one API call's input+output tokens to the turn's running total.
    # This is the spend budget (max_turn_tokens checks this), distinct from
    # current_tokens (window pressure, checked by needs_compaction?).
    def add_turn_tokens(input, output)
      @turn_tokens += input.to_i + output.to_i
    end

    # Update the known context size from the most recent response's
    # input_tokens -- the actual, current pressure on the window, not a
    # running total.
    def update_tokens(n)
      @current_tokens = n.to_i
    end

    # Fraction of the context window currently in use (0.0-1.0).
    def usage_fraction
      context_window.positive? ? current_tokens.to_f / context_window : 0.0
    end

    def usage_pct
      (usage_fraction * 100).round
    end

    # True once usage crosses compaction_threshold. Checked at the start of
    # a turn, before the next API call, not after every message.
    def needs_compaction?(threshold: compaction_threshold)
      usage_fraction >= threshold
    end

    # Drops the oldest ~40% of messages, keeping at least 2. current_tokens
    # resets to 0 since the true post-compaction size is unknown until the
    # next real API response reports it. Returns how many messages were
    # dropped, for logging.
    def compact_messages!(drop_fraction: 0.40)
      drop_count = [(messages.size * drop_fraction).ceil, messages.size - 2].min
      drop_count = [drop_count, 0].max
      @messages = messages.drop(drop_count)
      @current_tokens = 0
      drop_count
    end

    # Drops all history, keeping the system prompt and (via Registry,
    # untouched) every registered tool.
    def clear_messages!
      @messages = []
      @current_tokens = 0
    end

    def to_s
      "#<Context messages=#{messages.size} window=#{context_window} current=#{current_tokens} (#{usage_pct}%)>"
    end
  end
end
