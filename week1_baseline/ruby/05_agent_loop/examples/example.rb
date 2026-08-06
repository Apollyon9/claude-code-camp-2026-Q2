$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 5: Agent Loop ==="
puts

Boukensha::Config.new # loads .env from BOUKENSHA_DIR into ENV as a side effect
api_key = ENV["ANTHROPIC_API_KEY"]
unless api_key
  abort "No ANTHROPIC_API_KEY found. Set BOUKENSHA_DIR to a .boukensha/ directory with a .env containing it."
end

ctx = Boukensha::Context.new(
  system: "You are a terse MUD player agent. Use the look tool to see the room, " \
    "then the move tool to go through the only exit before giving a one-sentence summary."
)
registry = Boukensha::Registry.new
registry.tool("look", description: "Describe the room the player is standing in.") do
  "You are in a dimly lit tavern. The only exit is a door to the north."
end
registry.tool("move", description: "Move in a direction.", parameters: {direction: {type: "string"}}) do |direction:|
  "You walk #{direction} and step into a cobblestone street."
end

backend = Boukensha::Backends::Anthropic.new(api_key: api_key, model: "claude-haiku-4-5")
builder = Boukensha::PromptBuilder.new(ctx, registry, backend)
client  = Boukensha::Client.new(builder)
agent   = Boukensha::Agent.new(context: ctx, registry: registry, builder: builder, client: client, max_iterations: 6)

ctx.messages << Boukensha::Message.new(:user, "Look around and leave through the exit.")

puts "-- Running the agent loop (this makes real API calls) --"
result = agent.run

puts
puts "-- Final response --"
puts result

puts
puts "-- Full message history --"
ctx.messages.each { |m| puts m }
