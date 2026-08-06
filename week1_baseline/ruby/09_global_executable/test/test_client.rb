require_relative "test_helper"
require_relative "support/fake_http_server"

class TestClient < Minitest::Test
  FakeBuilder = Struct.new(:url, :headers, :payload) do
    def to_api_payload(max_output_tokens:, tools:)
      payload
    end
  end

  def teardown
    @server&.close
  end

  def build_client(port, payload: {model: "fake"})
    builder = FakeBuilder.new(
      "http://127.0.0.1:#{port}/v1/messages",
      {"x-api-key" => "fake-key", "anthropic-version" => "2023-06-01"},
      payload
    )
    Boukensha::Client.new(builder, base_retry_delay: 0)
  end

  def test_successful_call_returns_parsed_json
    body = {"stop_reason" => "end_turn", "content" => []}.to_json
    @server = FakeHttpServer.new([FakeHttpServer.response(status: 200, body: body)])

    result = build_client(@server.port).call
    assert_equal "end_turn", result["stop_reason"]
  end

  def test_sends_the_builders_payload_and_headers
    body = {"stop_reason" => "end_turn", "content" => []}.to_json
    @server = FakeHttpServer.new([FakeHttpServer.response(status: 200, body: body)])
    payload = {model: "claude-haiku-4-5", messages: [{role: "user", content: "look"}]}

    build_client(@server.port, payload: payload).call

    sent = @server.requests.first
    assert_equal "fake-key", sent.headers["x-api-key"]
    assert_equal payload.to_json, sent.body
  end

  def test_retries_on_retryable_status_then_succeeds
    ok_body = {"stop_reason" => "end_turn", "content" => []}.to_json
    @server = FakeHttpServer.new([
      FakeHttpServer.response(status: 503, body: ""),
      FakeHttpServer.response(status: 200, body: ok_body)
    ])

    result = build_client(@server.port).call
    assert_equal "end_turn", result["stop_reason"]
    assert_equal 2, @server.requests.size
  end

  def test_gives_up_after_max_retries_and_raises_api_error
    responses = Array.new(Boukensha::Client::MAX_RETRIES + 1) { FakeHttpServer.response(status: 503, body: "") }
    @server = FakeHttpServer.new(responses)

    error = assert_raises(Boukensha::ApiError) { build_client(@server.port).call }
    assert_match(/503/, error.message)
    assert_equal Boukensha::Client::MAX_RETRIES + 1, @server.requests.size
  end

  def test_non_retryable_status_raises_immediately
    @server = FakeHttpServer.new([FakeHttpServer.response(status: 401, body: "unauthorized")])

    assert_raises(Boukensha::ApiError) { build_client(@server.port).call }
    assert_equal 1, @server.requests.size
  end

  def test_connection_refused_raises_api_error_after_retries
    # Grab a free port and release it immediately -- nothing is listening,
    # so Net::HTTP hits a real Errno::ECONNREFUSED, no server needed at all.
    probe = TCPServer.new("127.0.0.1", 0)
    closed_port = probe.addr[1]
    probe.close

    error = assert_raises(Boukensha::ApiError) { build_client(closed_port).call }
    assert_match(/ECONNREFUSED/, error.message)
  end
end
