# 09 · Global Executable

Packages this as an installable gem so `boukensha` runs from anywhere on the
machine, no `bundle exec`, no relative path. Adds `boukensha.gemspec`,
`bin/boukensha`, and `Boukensha::Cli`.

```bash
cd 09_global_executable
gem build boukensha.gemspec
gem install --user-install boukensha-0.8.0.gem

boukensha --version              # boukensha 0.8.0
boukensha                        # starts the REPL
boukensha find the bakery        # one-shot task, prints the result, exits
```

## Skipped: `.boukensharc` / `BOUKENSHA_PATH`

The reference implementation adds a config file and env var here purely so
the instructor can flip between his own 13 parallel step-folder gem
versions while recording, `BOUKENSHA_PATH` env var → `.boukensharc` file →
bundled default. That solves a problem specific to maintaining many
simultaneously-installable competing versions of the same gem. This repo
only ever has one current version that matters at a time, built forward
through the step folders in git history, not thirteen live gems switched
between at runtime. Adding that machinery here would be solving a problem
this project doesn't have, so it's left out, one plain gem, one `boukensha`
command, the version installed is the version that runs.

## `Boukensha::Cli`, not inline script logic

`bin/boukensha` is two lines: `require "boukensha"` and
`Boukensha::Cli.new.call(ARGV)`. All the actual dispatch, `--version`/`-v`,
empty args starts the REPL, any other args run once as a task and print the
result, lives in `Cli`, with `run_task:`/`start_repl:` as injectable
constructor keywords defaulting to the real `Boukensha.run`/`.repl`. Same
pattern as `Repl`'s `input:`/`output:` from step 08: pulling the logic out
of a bare script is what makes it something `test_cli.rb` can actually
assert on, four argument-dispatch cases, zero network calls, zero live
terminal needed.

## Verified as a real global command, not just a passing test

Built the gem, installed it with `gem install --user-install`, then ran it
from `/tmp`, an unrelated directory, using the installed binary's full path
directly, no relative path, no `bundle exec`, confirming it's genuinely
running as an installed executable and not accidentally resolving to
something in the working directory:

```
$ cd /tmp
$ .../bin/boukensha --version
boukensha 0.8.0
$ .../bin/boukensha "Say hi in three words."
Hi there friend!
```

Both real, live behavior, not simulated. `--version` printed and exited
without touching the network; the one-shot task made a real call through
`Boukensha.run` and printed the actual result. Gem uninstalled and the
locally-built `.gem` file removed afterward, they're gitignored (`*.gem`)
and don't belong sitting in the working tree once verified.

## Code Changes

| File | Purpose |
|---|---|
| `boukensha.gemspec` | gem metadata, declares `boukensha` as the executable |
| `bin/boukensha` | two lines, delegates to `Cli` |
| `lib/boukensha/cli.rb` | `Boukensha::Cli` — argument dispatch, injectable for testing |
| `Gemfile` | now `gemspec` instead of listing runtime deps twice |
| `test/test_cli.rb` | all four dispatch paths, no network |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/09_global_executable
```

Runs the step's own `examples/example.rb` the same way every prior step
does. To actually try the installed global command, use the `gem build` /
`gem install` sequence above instead.
