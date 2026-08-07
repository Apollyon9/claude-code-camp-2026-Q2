$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 10: Standard Tool Library (MUD) ==="
puts
puts "Real Anthropic calls AND a real MUD session against the container on"
puts "port 4000, playing as dummy. See the README for the MudManager fixes"
puts "and character setup this depended on."
puts

Boukensha::Config.new # loads .env from BOUKENSHA_DIR into ENV
unless ENV["ANTHROPIC_API_KEY"]
  abort "No ANTHROPIC_API_KEY found. Set BOUKENSHA_DIR to a .boukensha/ directory with a .env containing it."
end

result = Boukensha.run(
  task: "Look around, tell me what's here, then check your own score.",
  max_iterations: 6
)

puts "-- Final response --"
puts result
