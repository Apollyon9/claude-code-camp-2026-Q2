# 03 · Prompt Builder

Adds `Boukensha::Backends::Base`, `Boukensha::Backends::Anthropic`, and
`Boukensha::PromptBuilder`. This is where the request actually gets built for
a specific provider's REST schema, and where the response gets normalized
back to one shape.

```ruby
backend = Boukensha::Backends::Anthropic.new(api_key: key, model: "claude-haiku-4-5")
builder = Boukensha::PromptBuilder.new(ctx, registry, backend)

builder.to_api_payload(max_output_tokens: 512)  # => full Anthropic request body
builder.parse_response(raw_response)            # => { stop_reason:, content: }
```

## Scope: one backend, not five

The reference implementation ships five backends (Anthropic, OpenAI, Gemini,
Ollama, Ollama Cloud). This build ships one, Anthropic, with a real
`Backends::Base` abstraction underneath it, model table, cost estimation,
`validate_model!` and `configure_model` all live on the base class already.
Adding a second backend later is meant to be an extension of that
abstraction, not a rewrite of it. A second backend gets added once there's an
actual reason to need one, not up front for its own sake.

## Where tools come from

`Context` holds conversation state, `Registry` holds tool state (see step
02). `Backends::Anthropic` never touches either directly, it only knows how
to turn plain messages/tools/system data into Anthropic's exact schema.
`PromptBuilder` is the one place that reaches into both `Context` and
`Registry` and hands the backend what it needs. That keeps the backend
testable against fixture data with no `Context` or `Registry` in sight, which
is exactly what `test/test_backends_anthropic.rb` does.

## Anthropic-specific schema quirks worth knowing

- A tool result is sent back as a **user** message wrapping a `tool_result`
  content block, not a dedicated role, even though the result came from
  Boukensha, not the human.
- Every parameter Boukensha declares for a tool ends up `required` in the
  schema sent to Anthropic. That's fine for tools this build fully controls,
  but would need fixing before plugging in an arbitrary third-party tool
  schema.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/backends/base.rb` | `Backends::Base` — model table lookup, validation, cost estimation |
| `lib/boukensha/backends/anthropic.rb` | `Backends::Anthropic` — request/response schema for the Messages API |
| `lib/boukensha/prompt_builder.rb` | `Boukensha::PromptBuilder` — assembles Context + Registry into a backend call |
| `lib/boukensha/errors.rb` | adds `UnsupportedModelError` |
| `examples/example.rb` | builds a real request payload, parses a simulated tool-use response, feeds the result back into the message history |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/03_prompt_builder
```

No API key needed. This step builds request/response shapes only, it never
makes an HTTP call, that's step 04.
