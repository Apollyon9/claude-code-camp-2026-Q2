module Boukensha
  # One callable capability the agent can invoke: a name and JSON-schema-style
  # description for the LLM, plus the Ruby block that actually runs it. The
  # block never reaches the model — only name/description/parameters do.
  Tool = Struct.new(:name, :description, :parameters, :block) do
    def to_s
      "#<Tool name=#{name} params=#{parameters.keys}>"
    end
  end
end
