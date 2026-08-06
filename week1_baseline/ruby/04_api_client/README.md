# 04 · API Client

Adds `Boukensha::Client`, the thing that actually makes the HTTP call.
Everything before this step built a request and could parse a response, but
nothing left the process. This step is the first place that does.

```ruby
client = Boukensha::Client.new(builder)
response = client.call(max_output_tokens: 512)   # real HTTP POST, real JSON back
```

`Client` deliberately knows nothing about tools or messages. It takes a
`builder`-shaped object (`url`, `headers`, `to_api_payload`), sends the
request, retries on transient failure, and returns the parsed JSON body or
raises `Boukensha::ApiError`.

## Stdlib only, on purpose

`Net::HTTP`, not Faraday or HTTParty. The tradeoff this buys: full visibility
into the request/response cycle at the cost of the OpenSSL cert path being
whatever the OS ships, rather than something a gem smooths over. Ran clean on
this machine (WSL2/Linux) without needing to hardcode `ca_file`, unlike the
reference implementation, which had to special-case macOS vs Linux.

## Retry behaviour

- Retries on `408, 409, 429, 500, 502, 503, 504` and on transient connection
  errors (`ECONNRESET`, `ECONNREFUSED`, timeouts, `SocketError`, SSL errors).
- `MAX_RETRIES = 3`, exponential backoff starting at `0.5s` (`0.5, 1, 2`).
- After retries are exhausted, a bad status returns to the caller and gets
  raised as `ApiError` there; a connection error raises `ApiError` directly
  from inside the retry loop, since there's no response object to hand back.

## Testing the retry path for real

`test/support/fake_http_server.rb` is a ~50-line raw `TCPServer`, stdlib
only, no mocking gem. It queues canned HTTP responses and hands the next one
to each accepted connection, recording the full request (headers + body) it
received. This lets `test/test_client.rb` prove, over a real socket:

- a 503 followed by a 200 actually retries and succeeds
- four straight 503s exhaust the retry budget and raise `ApiError`
- a non-retryable status (401) fails on the first attempt, no retry
- a genuinely closed port produces a real `ECONNREFUSED`, no simulation needed
- the exact bytes sent match what `PromptBuilder` built, headers included

`base_retry_delay:` is an optional constructor keyword so tests can run the
backoff path with `0` instead of real sleeps. Production call sites never
pass it.

## Verified against the real API

`examples/example.rb` makes an actual call to Anthropic using the key in
`.boukensha/.env`, not a simulated response. It sends "look around" with one
real tool registered, the model calls it, the tool actually runs, and the
result gets sent back for a real final answer. That's the first point in
this build where the whole loop, request → real model → tool call → real
dispatch → response, has been proven end to end, even though `Agent` itself
doesn't exist until step 05.

## Code Changes

| File | Purpose |
|---|---|
| `lib/boukensha/client.rb` | `Boukensha::Client` — HTTP call, retry/backoff |
| `lib/boukensha/errors.rb` | adds `ApiError` |
| `test/support/fake_http_server.rb` | stdlib-only fake server for exercising the real HTTP path |
| `examples/example.rb` | live call to Anthropic, real tool dispatch, real second call |

## Run it

```bash
BOUKENSHA_DIR="$(pwd)/.boukensha" ./week1_baseline/ruby/bin/04_api_client
```

Needs a real `ANTHROPIC_API_KEY` in `.boukensha/.env`. This one costs a
fraction of a cent to run, two Haiku calls.
