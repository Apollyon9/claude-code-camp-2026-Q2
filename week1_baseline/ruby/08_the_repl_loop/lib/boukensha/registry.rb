require_relative "tool"
require_relative "errors"

module Boukensha
  # Owns the tool table: registration and dispatch. The agent never calls a
  # tool directly, it hands the registry a name and args, and the registry
  # looks up the matching Tool and runs its block.
  class Registry
    def initialize
      @tools = {}
    end

    def tool(name, description:, parameters: {}, &block)
      t = Tool.new(name.to_s, description, parameters, block)
      @tools[t.name] = t
      t
    end

    def dispatch(name, args = {})
      t = @tools[name.to_s]
      raise UnknownToolError, "No tool registered as '#{name}'" unless t

      t.block.call(**args.transform_keys(&:to_sym))
    end

    def tools
      @tools
    end

    def tool_count = @tools.size
  end
end
