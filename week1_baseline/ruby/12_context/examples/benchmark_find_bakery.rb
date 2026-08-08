$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

# The instructor's own Week 1 benchmark, run against our finished baseline:
# find the bakery and list what it sells. Never run until now -- every
# per-step example used a scenario built to isolate that step's own
# mechanism (a tiny context window, capital cities, a two-tool room), not
# this. Tracks wall-clock time and token spend the same way the instructor's
# own office-hours numbers do (5-7 minutes / ~65,000 tokens before his
# optimization work), so this is directly comparable, not just a pass/fail.

puts "=== Week 1 Benchmark: find the bakery ==="
puts

Boukensha::Config.new
unless ENV["ANTHROPIC_API_KEY"]
  abort "No ANTHROPIC_API_KEY found. Set BOUKENSHA_DIR to a .boukensha/ directory with a .env containing it."
end

started_at = Time.now

result = Boukensha.run(
  task: "Find the bakery and tell me everything on its menu, with prices.",
  max_iterations: 25,
  max_turn_tokens: 60_000
)

elapsed = Time.now - started_at

puts "-- Final response --"
puts result
puts
puts "-- Elapsed: #{elapsed.round(1)}s --"
