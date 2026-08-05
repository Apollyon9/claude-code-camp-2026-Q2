$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 2: The Registry ==="
puts

ctx = Boukensha::Context.new(system: "You are a MUD player agent.")
registry = Boukensha::Registry.new

registry.tool("look", description: "Describe the room the player is standing in.") do
  "You are in a dimly lit tavern."
end
puts "Registered: #{registry.tools.keys}"

ctx.messages << Boukensha::Message.new(:user, "look around")
result = registry.dispatch("look")
ctx.messages << Boukensha::Message.new(:tool_result, result, "call_1")
ctx.messages.each { |m| puts m }

puts
begin
  registry.dispatch("attack")
rescue Boukensha::UnknownToolError => e
  puts "Dispatch failure (expected): #{e.message}"
end

puts
puts ctx
