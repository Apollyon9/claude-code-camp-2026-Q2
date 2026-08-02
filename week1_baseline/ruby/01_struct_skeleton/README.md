# 01 · Struct Skeleton

Carries forward `Config` and `Tasks` from step 00 unchanged, and adds the
three plain data containers everything else in this agent gets built on:

| Struct | Fields | Purpose |
|---|---|---|
| `Tool` | `name, description, parameters, block` | One callable capability: the schema the model sees, plus the Ruby code that runs it. |
| `Message` | `role, content, tool_use_id` | One conversation turn. `tool_use_id` links a `:tool_result` back to the call it answers. |
| `Context` | `system, messages, tools, context_window, working_dir` | Everything the agent knows right now: prompt, tool set, full history. |

No behaviour yet — no registry, no dispatch, no message-adding helpers. This
step is deliberately just the shapes; `examples/example.rb` builds and fills
them by hand (`ctx.tools[tool.name] = tool`, `ctx.messages <<`) to show what
each field is for before any code exists to do it automatically.

## Why structs, and why keyword defaults on Context

`Struct` keeps these readable while they're just data. `Tool` and `Message`
are plain positional structs. `Context` uses `keyword_init: true` with an
overridden `initialize` so `messages` and `tools` default to a fresh `[]` and
`{}` per instance — a positional struct default would share one array/hash
across every `Context` created, which is the kind of mutable-default bug
worth avoiding from the start.

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/../../.boukensha" ../bin/01_struct_skeleton
```

Or, from the repo root:

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/01_struct_skeleton
```
