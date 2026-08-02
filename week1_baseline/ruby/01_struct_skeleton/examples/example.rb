$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 1: Struct Skeleton ==="
puts

# No registry yet -- these are plain data containers, built and filled by hand.
ctx = Boukensha::Context.new(system: "You are a MUD player agent.")
puts ctx

look_tool = Boukensha::Tool.new(
  "look",
  "Describe the room the player is standing in.",
  {},
  -> { "You are in a dimly lit tavern." }
)
ctx.tools[look_tool.name] = look_tool
puts look_tool

ctx.messages << Boukensha::Message.new(:user, "look around")
ctx.messages << Boukensha::Message.new(:tool_result, look_tool.block.call, "call_1")
ctx.messages.each { |m| puts m }

puts
puts ctx
