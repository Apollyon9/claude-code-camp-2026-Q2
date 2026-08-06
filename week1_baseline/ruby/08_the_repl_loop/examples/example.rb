$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 8: The REPL Loop ==="
puts
puts "Driving Repl#run_turn directly (not #start) so this runs unattended --"
puts "same real API calls, scripted input instead of a live terminal."
puts

config = Boukensha::Config.new # loads .env from BOUKENSHA_DIR into ENV as a side effect
api_key = ENV["ANTHROPIC_API_KEY"]
unless api_key
  abort "No ANTHROPIC_API_KEY found. Set BOUKENSHA_DIR to a .boukensha/ directory with a .env containing it."
end

ctx = Boukensha::Context.new(system: "You are a terse MUD player agent. Track what the player is carrying.")
registry = Boukensha::Registry.new
registry.tool("look", description: "Describe the room the player is standing in.") do
  "A dusty wooden chest sits in the corner, lid open."
end
registry.tool("take", description: "Pick up an item.", parameters: {item: {type: "string"}}) do |item:|
  "You pick up the #{item}."
end

backend = Boukensha::Backends::Anthropic.new(api_key: api_key, model: "claude-haiku-4-5")
builder = Boukensha::PromptBuilder.new(ctx, registry, backend)
client  = Boukensha::Client.new(builder)
logger  = Boukensha::Logger.new(
  dir: File.join(config.dir, "sessions"),
  snapshot: {provider: "anthropic", model: "claude-haiku-4-5"}
)
repl = Boukensha::Repl.new(context: ctx, registry: registry, builder: builder, client: client, logger: logger, max_iterations: 6)

puts "-- Turn 1 --"
repl.run_turn("Look around and take whatever you find.")

puts
puts "-- Turn 2, same Repl, no new tools called --"
puts "-- (proves Context persists across turns and the shared Agent's iteration count actually resets) --"
repl.run_turn("What did you pick up earlier?")

logger.close

puts
puts "-- Full message history across both turns --"
ctx.messages.each { |m| puts m }
