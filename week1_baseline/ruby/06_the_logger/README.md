# 06 · The Logger

Adds `Boukensha::Logger`: writes one structured JSONL file per session, one
line per event (`iteration`, `tool_call`, `tool_result`, `response`,
`limit_reached`, `turn_end`), each carrying a `session_id` and timestamp.
Meant to be grepped and tailed, not read directly. `Agent` now logs at every
phase of the loop.

```ruby
logger = Boukensha::Logger.new(dir: File.join(config.dir, "sessions"), snapshot: {model: "claude-haiku-4-5"})
agent  = Boukensha::Agent.new(context: ctx, registry: registry, builder: builder, client: client, logger: logger)
agent.run
logger.close
```

## Why `dir:` is required, not defaulted from Config

The reference implementation's `Logger` reaches into `Boukensha.config.dir`
itself when no directory is given. Here `dir:` is a required keyword, the
caller resolves it. Constructing a `Logger` never has the hidden side effect
of loading `.env`/`settings.yaml` just to find out where to write; the
caller already knows its config dir by the time it needs a logger.

## `NullLogger`, so `Agent` never needs a real one

`Agent`'s default `logger:` is `NullLogger.new`, a same-interface class
where every method is a no-op. Every test from step 05 that doesn't care
about logging didn't need to change at all, and constructing an `Agent`
with no logger touches the filesystem exactly zero times. The reference
implementation defaults to a real `Logger.new`, which means the default
constructor call always creates a file on disk, a side effect that's easy
to not notice.

## Where logs live, and the plan for later

Session logs write to `<config_dir>/sessions/<session_id>.jsonl` — one
folder, so flipping it to gitignored later (once volume gets unmanageable,
which the instructor says happens by Week 2-3) is a one-line change, not a
restructure. For now they're committed, since that's the current instruction:
he uses them to confirm work actually ran. The plan going forward, matching
where he ended up himself: keep raw logs committed while they're still
small and reviewable, and once that stops being true, gitignore the raw
stream and deliberately promote a small curated set of "best logs" instead
of committing everything by default.

## A real gotcha: `log_viz` doesn't read `BOUKENSHA_DIR`

`log_viz` (the provided Sinatra viewer) has its own separate env var,
`LOG_VIZ_SESSIONS_DIR`, and otherwise defaults to a path computed relative
to its own file location, not to anything `Boukensha::Config` resolves.
Pointing `BOUKENSHA_DIR` at this repo's `.boukensha/` and starting `log_viz`
looks like it works (`/` returns `200`), but it's silently listing zero
sessions from a directory that doesn't exist, since its default and ours
don't coincide. Confirmed by actually opening a session in the browser, not
just checking the HTTP status:

```bash
LOG_VIZ_SESSIONS_DIR="$(pwd)/.boukensha/sessions" bundle exec ruby week1_baseline/ruby/log_viz/bin/log_viz
```

## Testing

`test/test_logger.rb` writes real files to a temp dir and reads them back as
parsed JSON, checking every event type, the `session_start` snapshot merge,
and that `close` doesn't drop already-written lines. `test/test_agent.rb`
gets a `SpyLogger` (records which methods were called with what, writes
nothing to disk) proving `Agent` actually calls the logger during a real
run, including the failure and wrap-up paths.

## Verified against the real API

`examples/example.rb` runs the same two-tool scenario as step 05, but with
a real `Logger` attached, and prints the resulting JSONL file at the end.
Every phase of a real 3-iteration run (`look` → `move` → final answer)
showed up in the log in order, tool args and results included.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/logger.rb` | `Boukensha::Logger` — JSONL session logging |
| `lib/boukensha/null_logger.rb` | `Boukensha::NullLogger` — same interface, no-op |
| `lib/boukensha/agent.rb` | logs iteration/tool_call/tool_result/response/limit_reached/turn_end |
| `test/test_logger.rb` | JSONL format, event shapes, snapshot merge |
| `test/test_agent.rb` | + `SpyLogger`, proves Agent actually logs |
| `examples/example.rb` | real run with a real Logger, prints the resulting file |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/06_the_logger
```

Needs a real `ANTHROPIC_API_KEY` in `.boukensha/.env`.
