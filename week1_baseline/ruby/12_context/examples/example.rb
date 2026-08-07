$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "boukensha"

puts "=== Boukensha Step 12: Context Management ==="
puts
puts "A deliberately tiny context_window (120 tokens) so real conversation"
puts "history actually crosses the compaction threshold within a few turns,"
puts "not a simulated trigger."
puts

Boukensha::Config.new
unless ENV["ANTHROPIC_API_KEY"]
  abort "No ANTHROPIC_API_KEY found. Set BOUKENSHA_DIR to a .boukensha/ directory with a .env containing it."
end

context  = Boukensha::Context.new(system: "You are a terse assistant.", context_window: 120, compaction_threshold: 0.85)
registry = Boukensha::Registry.new
backend  = Boukensha::Backends::Anthropic.new(api_key: ENV["ANTHROPIC_API_KEY"], model: "claude-haiku-4-5")
builder  = Boukensha::PromptBuilder.new(context, registry, backend)
client   = Boukensha::Client.new(builder)
logger   = Boukensha::Logger.new(
  dir: File.join(Boukensha::Config.new.dir, "sessions"),
  snapshot: {provider: "anthropic", model: "claude-haiku-4-5", context_window: 120}
)
repl = Boukensha::Repl.new(context: context, registry: registry, builder: builder, client: client, logger: logger, max_iterations: 3)

prompts = [
  "What's the capital of France?",
  "What's the capital of Japan?",
  "What's the capital of Brazil?",
  "What's the capital of Canada?",
  "What's the capital of Egypt?",
  "What's the capital of Kenya?",
  "What's the capital of Norway?",
  "What's the capital of Peru?"
]

prompts.each_with_index do |prompt, i|
  puts "-- Turn #{i + 1}: #{prompt} --"
  puts "   before: #{context.messages.size} messages, #{context.current_tokens} tokens (#{context.usage_pct}% of #{context.context_window})"
  repl.run_turn(prompt)
  puts "   after:  #{context.messages.size} messages, #{context.current_tokens} tokens (#{context.usage_pct}% of #{context.context_window})"
  puts
end

logger.close
puts "Session log: #{logger.path}"
