module Boukensha
  # Raised when the agent cannot be configured at all: no configuration
  # directory, no settings file, unreadable YAML, or a task with no system
  # prompt. These are setup mistakes, so they are raised at construction with
  # the path we looked at rather than left to surface as a confusing failure
  # later in the loop.
  class ConfigError < StandardError; end

  # Raised by Registry#dispatch when the agent asks for a tool name that was
  # never registered.
  class UnknownToolError < StandardError; end

  # Raised by Backends::Base.validate_model! when a backend is asked to
  # configure a model it has no MODELS entry for.
  class UnsupportedModelError < StandardError; end

  # Raised by Client#call when the request ultimately fails: a non-success
  # HTTP status, or a transient connection error that outlasted the retries.
  class ApiError < StandardError; end
end
