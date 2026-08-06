$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 9: Global Executable ==="
puts
puts "This exercises Boukensha::Cli directly, the same dispatch logic"
puts "bin/boukensha runs when installed as a real gem. See the README for"
puts "the gem build/install steps that prove it also works as an actual"
puts "global command from an unrelated directory."
puts

puts "-- boukensha --version --"
Boukensha::Cli.new.call(["--version"])

puts
puts "-- boukensha find the bakery (one-shot task, real API call) --"
Boukensha::Config.new # loads .env from BOUKENSHA_DIR into ENV
unless ENV["ANTHROPIC_API_KEY"]
  abort "No ANTHROPIC_API_KEY found. Set BOUKENSHA_DIR to a .boukensha/ directory with a .env containing it."
end

Boukensha::Cli.new.call(["Say", "hello", "in", "exactly", "five", "words."])
