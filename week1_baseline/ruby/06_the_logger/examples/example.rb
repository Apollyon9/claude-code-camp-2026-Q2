$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 6: The Logger ==="
puts

config = Boukensha::Config.new # loads .env from BOUKENSHA_DIR into ENV as a side effect
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
logger  = Boukensha::Logger.new(
  dir: File.join(config.dir, "sessions"),
  snapshot: {provider: "anthropic", model: "claude-haiku-4-5", max_iterations: 6}
)
agent = Boukensha::Agent.new(context: ctx, registry: registry, builder: builder, client: client, logger: logger, max_iterations: 6)

ctx.messages << Boukensha::Message.new(:user, "Look around and leave through the exit.")

puts "-- Running the agent loop (this makes real API calls) --"
result = agent.run
logger.close

puts
puts "-- Final response --"
puts result

puts
puts "-- Session log: #{logger.path} --"
File.readlines(logger.path).each { |line| puts line }
