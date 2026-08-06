# 05 · Agent Loop

Adds `Boukensha::Agent`, the class that turns everything built so far into
an actual loop instead of a script manually calling each piece in order.
This replaces the two-manual-calls dance step 04's example did by hand:
`Agent#run` calls the API, checks `stop_reason`, dispatches any tool calls,
appends the results, and repeats until the model gives a final answer.

```ruby
agent = Boukensha::Agent.new(context: ctx, registry: registry, builder: builder, client: client)
ctx.messages << Boukensha::Message.new(:user, "look around")
agent.run   # loops as many times as it needs to, returns the final text
```

## The stop condition, kept explicit

The instructor's own reference agent has this same loop, but on camera he
admits he can't easily trace where it actually stops, calling it "hidden
somewhere" in his own code. Here the loop has exactly two exits, both
`return` statements at the point they happen: a non-`tool_use` response
returns its text directly, and `iteration_limit_reached?` returns the result
of `wrap_up` before a new iteration starts. Nothing else in the method
returns, so there's one place to look, not several.

## The wrap-up call

Hitting `max_iterations` doesn't cut the agent off mid-thought. One more
call is made, tools disabled, asking for a short summary of where it got to.
That call runs outside the counted loop: it can never re-trigger the limit,
since `@iteration` is never incremented for it. If the wrap-up call itself
fails (`ApiError`) or comes back empty, a fixed fallback message is used
instead of letting either failure surface as a crash.

## Tool errors don't crash the turn

If `registry.dispatch` raises (unknown tool, bad args), the loop catches it
and turns it into a normal `tool_result` message starting `ERROR: ...`
instead of letting the exception end the run. The model sees its own mistake
and can react to it on the next iteration, the same way it would see any
other tool result.

## Testing it without real API calls in the fast suite

`test/test_agent.rb` fakes only `Client`, the actual network boundary,
returning queued raw Anthropic-shaped responses. Everything else, response
parsing, tool-result formatting, is the real `PromptBuilder` and
`Backends::Anthropic` from steps 03-04, already covered by their own tests.
Covers: an immediate final answer, a tool call followed by a final answer,
an unknown tool degrading to an error result instead of crashing, hitting
`max_iterations` and triggering wrap-up with tools disabled, and the wrap-up
call itself failing or returning empty text.

## Verified against the real API

`examples/example.rb` registers two tools (`look`, `move`) and lets
`Agent#run` decide the sequence itself, no hand-holding through fixed steps.
A real run: `look` → model decides to `move` → tool runs → model gives a
one-sentence final summary, three real API calls, chosen by the model, not
scripted.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/agent.rb` | `Boukensha::Agent` — the loop, tool dispatch, wrap-up |
| `test/test_agent.rb` | loop behaviour, tool errors, max_iterations wrap-up, fake `Client` only |
| `examples/example.rb` | real multi-tool agent run against Anthropic |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/05_agent_loop
```

Needs a real `ANTHROPIC_API_KEY` in `.boukensha/.env`. Runs 2-4 real Haiku
calls depending on what the model decides to do.
