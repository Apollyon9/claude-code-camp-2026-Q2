$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 7: The Run DSL ==="
puts
puts "Everything step 06's example wired by hand -- Config, Context, Registry,"
puts "Backends::Anthropic, PromptBuilder, Client, Logger, Agent -- is now one call."
puts

result = Boukensha.run(
  task: "Look around and leave through the exit.",
  system: "You are a terse MUD player agent. Use the look tool to see the room, " \
    "then the move tool to go through the only exit before giving a one-sentence summary.",
  max_iterations: 6
) do
  tool("look", description: "Describe the room the player is standing in.") do
    "You are in a dimly lit tavern. The only exit is a door to the north."
  end
  tool("move", description: "Move in a direction.", parameters: {direction: {type: "string"}}) do |direction:|
    "You walk #{direction} and step into a cobblestone street."
  end
end

puts "-- Final response --"
puts result
