module Boukensha
  # Same interface as Logger, does nothing. Agent's default logger, so
  # constructing an Agent without one never touches the filesystem.
  class NullLogger
    def session_id = nil
    def path = nil
    def iteration(**) = nil
    def tool_call(**) = nil
    def tool_result(**) = nil
    def response(**) = nil
    def limit_reached(**) = nil
    def turn_end(**) = nil
    def compaction(**) = nil
    def close = nil
  end
end
