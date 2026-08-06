require_relative "message"

module Boukensha
  # Everything the agent knows for the current turn: the system prompt and
  # the full conversation history so far. Tool storage lives on Registry, not
  # here — a Context is conversation state, not a capability table.
  Context = Struct.new(:system, :messages, :context_window, :working_dir, keyword_init: true) do
    def initialize(system:, messages: [], context_window: 200_000, working_dir: nil)
      super
    end

    def to_s
      "#<Context messages=#{messages.size} window=#{context_window}>"
    end
  end
end
