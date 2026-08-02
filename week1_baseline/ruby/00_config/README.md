# 00 · Configuration

A single source of truth for everything the agent needs at startup: where its
config lives, what secrets it has, and what each task is set up to do.

## Config directory resolution

1. **`BOUKENSHA_DIR` env var** — points at any directory.
2. **`~/.boukensha`** — the default, real, gitignored, holds `.env`.

The repo also ships a committed `.boukensha/` at the repo root with a sample
`settings.yaml` and prompt override — useful for running the examples without
setting up a real config dir first, but it holds no secrets and is not where
your `ANTHROPIC_API_KEY` should live. Point `BOUKENSHA_DIR` at it, or at your
own `~/.boukensha`, when running any example in this repo:

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/00_config
```

Expected layout:

```
.boukensha/
  .env                 # secrets, e.g. ANTHROPIC_API_KEY (never committed)
  settings.yaml         # non-secret settings
  prompts/
    <task>/
      system.md         # per-task system prompt override (optional)
```

A missing `settings.yaml` is treated as a setup mistake, not a default-to-empty
case — `Config.new` raises `Boukensha::ConfigError` naming the directory it
looked in.

## Tasks

A task is one role in the agentic loop, bound to its own provider and model.
Week 1 only drives a single task, `player`, the main loop. `Boukensha::Tasks::Base`
is stateless — every method takes the task's settings hash as an argument
rather than the class holding config as instance state:

```ruby
config.tasks(:player)
# => {"provider" => "anthropic", "model" => "claude-haiku-4-5", ...}

Boukensha::Tasks::Player.provider(config.tasks(:player))       # => "anthropic"
Boukensha::Tasks::Player.model(config.tasks(:player))          # => "claude-haiku-4-5"
Boukensha::Tasks::Player.system_prompt(
  config.tasks(:player),
  user_prompts_dir: config.user_prompts_dir,
  default_prompts_dir: Boukensha::Config::PROMPTS_DIR
)
```

## System prompt resolution

Per task:

1. `.boukensha/prompts/<task>/system.md`, when the task's
   `prompt_override.system` setting is `true` and the file exists.
2. `prompts/system.md`, the default shipped with the library.

## Configuration schema, so far

```yaml
tasks:
  player:
    provider: anthropic
    model: claude-haiku-4-5
    prompt_override:
      system: true
mud:
  host: localhost
  port: 4000
  username: dummy
  password: helloworld
```

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/00_config
```
