module Boukensha
  # Static model -> context_window table. context_window is a known *model*
  # fact, the physical input ceiling, not something a user configures. It
  # has to be knowable before a backend is even constructed, so Context can
  # be sized correctly from the start rather than left at some placeholder
  # until the first real API response reports usage. Unknown models fall
  # back to a conservative default rather than silently assuming a huge
  # window.
  module Models
    TABLE = {
      "claude-haiku-4-5"  => 200_000,
      "claude-sonnet-4-6" => 1_000_000,
      "claude-opus-4-8"   => 1_000_000
    }.freeze

    DEFAULT_CONTEXT_WINDOW = 200_000

    def self.context_window(model)
      TABLE.fetch(model.to_s, DEFAULT_CONTEXT_WINDOW)
    end
  end
end
