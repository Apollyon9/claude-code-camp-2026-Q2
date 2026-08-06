$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"
require "json"

puts "=== Boukensha Step 3: Prompt Builder ==="
puts

ctx = Boukensha::Context.new(system: "You are a MUD player agent.")
registry = Boukensha::Registry.new
registry.tool("look", description: "Describe the room the player is standing in.") { "You are in a dimly lit tavern." }
registry.tool("move", description: "Move in a direction.", parameters: {direction: {type: "string"}}) { |direction:| "You walk #{direction}." }

# A fake key is fine here -- this step only builds request/response shapes,
# it does not make an HTTP call. That's step 04.
backend = Boukensha::Backends::Anthropic.new(api_key: "fake-key-for-demo", model: "claude-haiku-4-5")
builder = Boukensha::PromptBuilder.new(ctx, registry, backend)

ctx.messages << Boukensha::Message.new(:user, "look around")

puts "-- Request payload --"
puts JSON.pretty_generate(builder.to_api_payload(max_output_tokens: 512))

puts
puts "-- Simulated Anthropic response, stop_reason: tool_use --"
fake_response = {
  "stop_reason" => "tool_use",
  "content" => [
    {"type" => "text", "text" => "Let me check the room."},
    {"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}
  ]
}
parsed = builder.parse_response(fake_response)
puts JSON.pretty_generate(parsed)

puts
puts "-- Feeding the tool result back in --"
result = registry.dispatch("look")
ctx.messages << Boukensha::Message.new(:assistant, fake_response["content"])
ctx.messages << Boukensha::Message.new(:tool_result, result, "call_1")
puts JSON.pretty_generate(builder.to_messages)
