module Boukensha
  # One entry in the conversation history. `role` is :user, :assistant, or
  # :tool_result. `tool_use_id` is only set on a :tool_result message, linking
  # it back to the tool_use block it answers.
  Message = Struct.new(:role, :content, :tool_use_id) do
    def to_s
      id_tag = tool_use_id ? " [#{tool_use_id}]" : ""
      "#<Message role=#{role}#{id_tag} content=#{content.to_s[0..60]}>"
    end
  end
end
