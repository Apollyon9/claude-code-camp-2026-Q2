module Boukensha
  # The object `self` becomes inside a Boukensha.run { } block. Exposes only
  # `tool`, so callers can register ad-hoc tools inline alongside the task
  # without the DSL surface growing beyond what it needs to.
  class RunDSL
    def initialize(registry)
      @registry = registry
    end

    def tool(name, description:, parameters: {}, &block)
      @registry.tool(name, description: description, parameters: parameters, &block)
    end
  end
end
