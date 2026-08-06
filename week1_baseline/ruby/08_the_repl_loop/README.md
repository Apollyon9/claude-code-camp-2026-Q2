# 08 · The REPL Loop

Adds `Boukensha::Repl`, an interactive session that stays alive across
turns, and `Boukensha.repl` alongside `Boukensha.run`. Adds
`Boukensha::VERSION`.

```ruby
Boukensha.repl do
  tool("look", description: "...") { "a tavern" }
end
# reads a line, runs it, prints the reply, loops -- /clear /exit /quit /help
```

## One `Agent`, reused across every turn — and the bug that exposes

`Repl` builds one `Agent` in its constructor and reuses it for every turn,
rather than constructing a fresh one per turn. The reference implementation
does the opposite: a new `Agent` gets built on every single turn, something
the instructor catches live and calls "a bit of a defect," then leaves
unfixed to avoid disturbing later steps.

Reusing one instance is the better design (one object, one clear owner of
the loop's state), but it exposed a real bug `Agent` didn't have before:
`@iteration` was only ever incremented, never reset. A brand-new `Agent` per
turn never hits this, since a fresh object always starts at zero. Reusing
one instance means a second turn would inherit whatever iteration count the
first turn left behind and could hit `max_iterations` immediately, even
though that turn just started. Fixed by resetting `@iteration = 0` at the
top of `Agent#run` — one line, with a regression test in both
`test_agent.rb` (one `Agent`, two `.run` calls) and `test_repl.rb` (same
thing, through a `Repl`).

The instructor's own inefficiency and the bug it happens to hide are two
sides of the same design decision. Fixing the wasteful part first is what
surfaced the correctness problem.

## Commands

`/clear` (wipe history, tools stay registered since they live on `Registry`,
not `Context`), `/exit` / `/quit`, `/help`. The reference also has `/quiet`
and `/loud`, which the instructor himself wasn't sure did anything on
camera. Left out here rather than carrying forward flags with no confirmed
behavior.

## Testable without a live terminal

`input:`/`output:` are constructor keywords, defaulting to `$stdin`/`$stdout`
but swappable for a `StringIO`. `test_repl.rb` drives `#start` with scripted
input lines and asserts on captured output: blank/whitespace-only lines get
skipped (`.strip`, not `.chomp` — a whitespace-only line isn't empty after
just stripping the trailing newline, caught by an early version of the test
that queued one response but got two calls), unknown commands don't crash
the loop, `/exit` stops before ever touching the client.

## Verified against the real API

`examples/example.rb` runs two real turns through one `Repl`. Turn one looks
around and takes an item; turn two, no new tool calls at all, asks "what did
you pick up earlier" and gets the right answer purely from `Context`'s
shared history. That's the fix from above, proven live, not just in a fake
client.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/repl.rb` | `Boukensha::Repl` — the interactive loop, commands |
| `lib/boukensha/version.rb` | `Boukensha::VERSION` |
| `lib/boukensha/agent.rb` | resets `@iteration` at the start of every `#run` |
| `lib/boukensha.rb` | adds `Boukensha.repl`; `.run`/`.repl` now share setup via a private `build_stack` |
| `test/test_agent.rb` | regression test: one `Agent`, two `#run` calls, fresh budget each time |
| `test/test_repl.rb` | commands, cross-turn `Context` persistence, scripted `#start` |
| `examples/example.rb` | two real turns, second one answered from memory alone |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/08_the_repl_loop
```

Needs a real `ANTHROPIC_API_KEY` in `.boukensha/.env`.
