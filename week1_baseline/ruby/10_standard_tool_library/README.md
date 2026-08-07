# 10 · Standard Tool Library (MUD)

Wires the provided `MudManager` SDK into Boukensha as real agent tools. This
is the first step where the agent can actually play the MUD, not just talk.

```ruby
Boukensha.run(task: "Look around and tell me what's here.")
# mud: nil (default) auto-connects using settings.yaml's mud: block
```

## Grouped tools, not a 1:1 wrapper

`MudManager::Primitives` exposes around 50 stateless command builders. The
instructor's own reference wraps them almost one-for-one as agent tools and
calls the result "a little bit undercooked" on camera. `Tools::Mud` groups
them into 13 purposeful tools instead: `look`, `move`, `check_self`,
`consider`, `attack`, `flee`, `posture`, `get_item`, `drop_item`,
`give_item`, `equip`, `talk`, `rest_recover`. `check_self` alone covers nine
`info_self` sub-verbs (`exits`, `inventory`, `score`, ...) behind one
parameterized `kind:` enum instead of nine separate tools; `talk` covers
both local and targeted speech the same way.

This is still a baseline, not the token-optimized composite tools
(`inspect_room`, `travel`) the office-hours transcripts describe building in
Week 2/3 once real play-cost data exists to justify them. Grouping the raw
primitives is the improvement worth making now; deciding which multi-step
patterns are common enough to deserve their own composite tool needs actual
play data this baseline doesn't have yet.

## No connect/login tool, on purpose

The agent never decides to connect or log in, `Tools::Mud::Connector` does
it lazily on the first real tool call and reuses the same session for every
call after that (`test_session_is_only_opened_and_logged_in_once` proves
it). Connection lifecycle is a deterministic, framework-level concern, the
same reasoning the course's own MCP work landed on for exactly this
question: "the daemon owns the session lifecycle internally... the LLM only
ever sees gameplay tools."

## What this depended on: two real MudManager problems, fixed first

Before any of this could be built, testing `MudManager::Session#login`
against the real container (not assumed) turned up two separate problems,
both fixed in `week0_explore/mud_manager` directly and covered in that
commit:

1. `login()` had no idea this MUD confirms a brand-new name
   ("Did I get that right, Name (Y/N)?") before ever asking for a password.
   It just timed out. Fixed to recognize the prompt and fail fast with a
   clear `LoginError` instead.
2. `dummy` (the character `settings.yaml` is built around) wasn't actually
   registered in this container, and creating it fresh triggered
   CircleMUD's own "first character in an empty database becomes a level-34
   god" rule, exactly what `HOW_TO_PLAY.md` warns about. Fixed outside the
   codebase: a second character absorbed the first-character promotion,
   `dummy` got deleted and recreated clean as an ordinary level-1 mortal,
   verified via `score`.

Neither of these would have surfaced without actually connecting to the
live container. Assuming the provided SDK worked would have meant building
this whole tool layer on a foundation that couldn't log in at all.

## Testing without a live MUD in the fast suite

`test_tools_mud.rb` uses a `FakeSession` (open?/open/login/send_command/
read_until_quiet, no real socket), the same injectable-collaborator pattern
as `Client`'s fake HTTP server and `Repl`'s `input:`/`output:`. Covers all
13 registered tools, that a `MudManager::Primitives::Command`'s `.raw` text
matches what was actually sent, and that the session connects/logs in
exactly once no matter how many tools get called after that.

## Verified against the real MUD and the real API together

`examples/example.rb` runs `Boukensha.run` with no mocking anywhere: real
Anthropic call, real telnet session, real `dummy` character. A live run
called `look`, then `check_self(kind: "score")`, and correctly reported
"Dummy the Swordpupil (Level 1)" with real live stats back to the user.

One real, harmless quirk showed up in that same run: the model called
`look(target: "room")`, and the MUD replied "You do not see that here,"
since "room" isn't an actual in-game object. Not a bug, `target` is
free-text and the model guessed a word that doesn't resolve to anything.
Left as-is rather than adding validation for a scenario that costs nothing
and teaches the model something real about the world it's in.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/tools/mud.rb` | `Tools::Mud` — the 13 grouped tools, lazy `Connector` |
| `lib/boukensha.rb` | adds `mud:` to `.run`/`.repl`, auto-resolves from `settings.yaml` |
| `boukensha.gemspec`, `Gemfile` | `mud_manager` as a runtime dependency, local `path:` override |
| `test/test_tools_mud.rb` | all 13 tools, connect-once behavior, fake session |
| `week0_explore/mud_manager/lib/mud_manager/session.rb` | (separate commit) the `login()` fix this step depended on |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/10_standard_tool_library
```

Needs the MUD container up on port 4000 and a real `ANTHROPIC_API_KEY` in
`.boukensha/.env`.
