$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"
require "json"

puts "=== Boukensha Step 4: API Client ==="
puts

Boukensha::Config.new # loads .env from BOUKENSHA_DIR into ENV as a side effect
api_key = ENV["ANTHROPIC_API_KEY"]
unless api_key
  abort "No ANTHROPIC_API_KEY found. Set BOUKENSHA_DIR to a .boukensha/ directory with a .env containing it."
end

ctx = Boukensha::Context.new(system: "You are a terse MUD player agent. Always use the look tool when asked to look.")
registry = Boukensha::Registry.new
registry.tool("look", description: "Describe the room the player is standing in.") { "You are in a dimly lit tavern. A bartender polishes a glass." }

backend = Boukensha::Backends::Anthropic.new(api_key: api_key, model: "claude-haiku-4-5")
builder = Boukensha::PromptBuilder.new(ctx, registry, backend)
client  = Boukensha::Client.new(builder)

ctx.messages << Boukensha::Message.new(:user, "look around")

puts "-- Sending a real request to Anthropic --"
response = client.call(max_output_tokens: 256)
parsed = builder.parse_response(response)
puts "stop_reason: #{parsed[:stop_reason]}"
puts JSON.pretty_generate(parsed[:content])

if parsed[:stop_reason] == "tool_use"
  call = parsed[:content].find { |b| b["type"] == "tool_use" }
  puts
  puts "-- Model called '#{call["name"]}', dispatching for real --"
  result = registry.dispatch(call["name"], call["input"])
  puts "Result: #{result}"

  ctx.messages << Boukensha::Message.new(:assistant, parsed[:content])
  ctx.messages << Boukensha::Message.new(:tool_result, result, call["id"])

  puts
  puts "-- Sending the tool result back for a final answer --"
  response2 = client.call(max_output_tokens: 256, tools: [])
  parsed2 = builder.parse_response(response2)
  text = parsed2[:content].select { |b| b["type"] == "text" }.map { |b| b["text"] }.join
  puts "Final response: #{text}"
end
