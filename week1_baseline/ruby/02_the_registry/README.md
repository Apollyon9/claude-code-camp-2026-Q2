# 02 · The Registry

Adds `Boukensha::Registry`, the single owner of the tool table. The agent
never calls a tool directly; it hands the registry a name and args, and the
registry looks up the matching `Tool` and runs its block.

```ruby
registry = Boukensha::Registry.new
registry.tool("look", description: "...") { "You are in a dimly lit tavern." }
registry.dispatch("look")          # => "You are in a dimly lit tavern."
registry.dispatch("attack")        # => raises Boukensha::UnknownToolError
```

## A deliberate difference from the reference

The instructor's own reference implementation adds a registry at this same
step but leaves `Context` still holding the `tools` hash directly underneath
it, so the registry ends up as a thin facade rather than the real owner. He
catches this live while building later steps and calls it a genuine defect,
one he says he plans to fix "when we get to week two" — it's never actually
fixed anywhere in his Week 1 code.

`Context` here has no `tools` field at all. Tool storage is a capability
concern, not conversation state, so it belongs on `Registry` alone.
`Context` went from `system, messages, tools, context_window, working_dir`
down to `system, messages, context_window, working_dir`.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/registry.rb` | `Boukensha::Registry` — tool registration + dispatch |
| `lib/boukensha/context.rb` | `tools` field removed |
| `lib/boukensha/errors.rb` | adds `UnknownToolError` |
| `examples/example.rb` | registers a tool, dispatches it, and dispatches an unknown name to show the error path |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/02_the_registry
```
