# 07 · The Run DSL

Adds `Boukensha.run` and `Boukensha::RunDSL`. Everything step 06's example
wired by hand, Config, Context, Registry, a backend, PromptBuilder, Client,
Logger, Agent, collapses to one call:

```ruby
result = Boukensha.run(task: "Look around and leave through the exit.") do
  tool("look", description: "...") { "a tavern" }
  tool("move", description: "...", parameters: {direction: {type: "string"}}) { |direction:| "..." }
end
```

## `Tasks::Player` finally has a caller

`Boukensha::Tasks::Player` has existed since step 00, resolving provider,
model, and system prompt from `settings.yaml`'s `tasks.player` block, but no
example ever actually called it, every prior step passed those values in
directly. `Boukensha.run` is the first place that reads `settings.yaml`
through it: `model:`, `system:`, and `backend:` are all optional overrides,
and when omitted, `Tasks::Player.provider` / `.model` / `.system_prompt`
resolve them from config the way the class was designed to be used from the
start.

## `RunDSL`, kept deliberately small

`RunDSL` exposes exactly one method, `tool`. Inside the block passed to
`Boukensha.run`, `self` is a `RunDSL` instance (via `instance_eval`), so
`tool(...)` reads like part of the DSL rather than a method call on some
object you have to know about. It does nothing but forward to
`Registry#tool` — the DSL surface stays small on purpose, matching the
instructor's own framing of this step as "basically making an SDK for our
agent."

## What's still not unit-testable here, and why

`Boukensha.run` always builds a real `Client` bound to Anthropic's real URL,
there's no seam to redirect that network call without adding one to the
public API purely for testing. `test/test_boukensha_run.rb` covers what
*can* be proven without touching the network: a missing model raises
`ConfigError`, an unsupported backend raises `ArgumentError`, and both
happen before any request would go out, so overriding `model:`/`system:`
directly (skipping `settings.yaml` reads entirely) still trips the same
backend check safely. The actual request/response wiring is already covered
by `Client`, `Agent`, and `PromptBuilder`'s own tests from earlier steps;
this step's own correctness is proven by a live run instead.

## Verified against the real API

`examples/example.rb` runs the exact same two-tool scenario as step 06's
example, `look` then `move` then a summary, but through `Boukensha.run`
instead of seven manually-constructed objects. Model, provider, and system
prompt all resolved from `.boukensha/settings.yaml`, not hardcoded in the
script. A new session log appeared under `.boukensha/sessions/` from the
real run, same as every prior step.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/run_dsl.rb` | `Boukensha::RunDSL` — the `tool` DSL surface |
| `lib/boukensha.rb` | adds `Boukensha.run`, wiring everything via `Tasks::Player` |
| `test/test_run_dsl.rb` | `RunDSL#tool` reaches the registry |
| `test/test_boukensha_run.rb` | the two setup errors that don't require network |
| `examples/example.rb` | the whole stack through one call, live |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/07_the_run_dsl
```

Needs a real `ANTHROPIC_API_KEY` in `.boukensha/.env`.
