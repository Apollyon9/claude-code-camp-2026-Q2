require_relative "tool"
require_relative "message"

module Boukensha
  # Everything the agent knows for the current turn: the system prompt, the
  # tools it can call, and the full conversation history so far. Plain data
  # at this step — Context grows real behaviour (compaction, token tracking)
  # once the agent loop exists to need it.
  Context = Struct.new(:system, :messages, :tools, :context_window, :working_dir, keyword_init: true) do
    def initialize(system:, messages: [], tools: {}, context_window: 200_000, working_dir: nil)
      super
    end

    def to_s
      "#<Context messages=#{messages.size} tools=#{tools.size} window=#{context_window}>"
    end
  end
end
