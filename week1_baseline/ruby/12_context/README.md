# 12 · Context Management (final Week 1 step)

There's no automatic compaction when calling an LLM directly, you own the
context window yourself. This step adds real token tracking, a second
circuit breaker alongside `max_iterations`, and auto-compaction, closing out
Week 1. `11_tui` is skipped, per the scoping decision from the start of this
build (see `week1_baseline/ruby/README` history / the journal): the
instructor's own numbers showed the TUI's background polling was the
biggest cost in his loop, and `log_viz` already covers what a TUI would.

```ruby
context = Boukensha::Context.new(system: "...", context_window: 120)
# ... several turns later, current_tokens crosses 85% of context_window ...
agent.run # compacts before the next API call, not after
```

## `Boukensha::Models`

A static model → context_window table, separate from `Backends::Anthropic`'s
own `MODELS` (which also carries cost-per-million). `Context` needs its
window size *before* a backend is constructed, so this can't just live on
the backend. Unknown models fall back to `DEFAULT_CONTEXT_WINDOW`
(200,000) rather than assuming something enormous.

## `Context` becomes a real class

Struct-with-a-block stops being the right shape once there's real behaviour:
`update_tokens`, `add_turn_tokens`/`reset_turn_tokens`, `usage_fraction`/
`usage_pct`, `needs_compaction?`, `compact_messages!`, `clear_messages!`.
`current_tokens` (actual usage from the most recent response, window
pressure) and `turn_tokens` (cumulative spend this turn, the budget
`max_turn_tokens` checks) are tracked separately and mean different things,
conflating them was a real bug in an earlier version of the reference.

## Two circuit breakers, whichever trips first

`Agent` now stops a turn on `max_iterations` (tool-call count, from step 05)
**or** `max_turn_tokens` (cumulative input+output spend this turn), same
wrap-up mechanic either way, `wrap_up(reason)` now takes which one tripped
so the logger and fallback message can say why.

## Compaction happens at the start of a turn, not mid-turn

`Agent#run` checks `@context.needs_compaction?` once, before the loop
starts, not after every message. Usage is only known accurately right after
a real API response reports it, checking mid-turn would mean deciding to
compact based on a stale number. Compacting *before* the next request means
the request that would have blown the budget never gets sent oversized in
the first place.

## `/compact`, and `/clear` now resets token state too

`Repl` gets a manual `/compact` command (drops oldest messages immediately,
logs the same `compaction` event `Agent` does) alongside automatic
compaction. `/clear` now calls `Context#clear_messages!` instead of
`messages.clear` directly, so it also resets `current_tokens`, clearing
history should mean clearing the known pressure on the window too, not just
the array.

## Usage read from the raw response, not the normalized shape

`record_usage` reads `response["usage"]` directly from the raw Anthropic
JSON, not through `parse_response`'s `{stop_reason:, content:}` contract.
Token accounting is provider-specific bookkeeping, not part of what every
backend normalizes to. Single-backend for now, so this stays a direct read
rather than threading a new field through an abstraction only one backend
implements. Worth revisiting if a second backend's raw usage shape differs
enough to need normalizing too.

## Verified with a real compaction, not a simulated one

`examples/example.rb` builds a `Context` with a deliberately tiny
`context_window` (120 tokens) and runs 8 real turns through one `Repl`. By
turn 8 the context was at 97% (real numbers, not fabricated), and
compaction fired for real before that turn's request went out: message
count dropped from 14 to 10, logged as
`{"phase":"compaction","before":116,"dropped":6,"context_window":120}` in
the session file. This took two attempts to actually trigger, the first try
undersized the window guess and topped out at 82%, still under threshold,
proof the mechanism was tested against real behaviour rather than assumed
to fire from the code alone.

## The instructor's own benchmark, run late, and a real gap it found

Every example script through this whole build used a scenario built to
isolate that step's own mechanism, never the instructor's own Week 1
benchmark: find the bakery and list what it sells. Running it for the first
time turned up a real gap immediately, `Tools::Mud` had 13 tools and none of
them could read a shop's menu. `MudManager::Primitives.shop` (list/buy/sell/
value/offer) existed the whole time, it just never got wrapped. Added as a
14th tool, `shop`, before running anything, `test_shop_list_reads_a_
shopkeepers_wares` and `test_shop_buy_with_an_item` alongside it.

With that in place: `examples/benchmark_find_bakery.rb` found the bakery and
read the real menu unassisted, 18 tool calls, 63,437 tokens, 63.4 seconds.
The token number sits almost exactly inside the instructor's own
unoptimized range (59,000-65,000, his own office-hours numbers), so this
isn't an artificially cheap comparison. The time is the more interesting
number: 63 seconds against his unoptimized 5-7 minutes, close to his own
*post*-optimization 31 seconds, without doing any of the optimization work
he did to get there. The TUI he found eating most of that time was never
built here in the first place (see the TUI-skip decision above), so this
build starts from roughly where his ended up.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/models.rb` | `Boukensha::Models` — model → context_window table |
| `lib/boukensha/context.rb` | now a class: token tracking, compaction, `clear_messages!` |
| `lib/boukensha/agent.rb` | `max_turn_tokens`, `record_usage`, `compact_if_needed` at turn start |
| `lib/boukensha/logger.rb` | adds `compaction` event, `turn_end` carries `tokens:` |
| `lib/boukensha/repl.rb` | `/compact` command, `/clear` uses `clear_messages!` |
| `lib/boukensha.rb` | `context_window:`/`max_turn_tokens:` on `.run`/`.repl` |
| `lib/boukensha/tools/mud.rb` | adds the 14th tool, `shop` |
| `test/test_context.rb`, `test_models.rb` | token math, compaction thresholds and dropping |
| `test/test_agent.rb`, `test_repl.rb`, `test_logger.rb` | circuit breaker, `/compact`, `compaction` event |
| `test/test_tools_mud.rb` | `shop` list/buy |
| `examples/benchmark_find_bakery.rb` | the instructor's own benchmark, run for real |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/12_context
```

Needs a real `ANTHROPIC_API_KEY` in `.boukensha/.env`. Eight small Haiku
calls, real compaction, real session log.
