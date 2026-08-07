require_relative "test_helper"

class TestBackendsAnthropic < Minitest::Test
  def setup
    @backend = Boukensha::Backends::Anthropic.new(api_key: "fake-key", model: "claude-haiku-4-5")
  end

  def test_rejects_unsupported_model
    assert_raises(Boukensha::UnsupportedModelError) do
      Boukensha::Backends::Anthropic.new(api_key: "fake-key", model: "gpt-5")
    end
  end

  def test_to_messages_passes_user_and_assistant_through
    messages = [
      Boukensha::Message.new(:user, "look around"),
      Boukensha::Message.new(:assistant, "You are in a tavern.")
    ]
    result = @backend.to_messages(messages)

    assert_equal({role: "user", content: "look around"}, result[0])
    assert_equal({role: "assistant", content: "You are in a tavern."}, result[1])
  end

  def test_to_messages_wraps_tool_result_as_a_user_message
    messages = [Boukensha::Message.new(:tool_result, "a tavern", "call_1")]
    result = @backend.to_messages(messages)

    assert_equal "user", result[0][:role]
    block = result[0][:content].first
    assert_equal "tool_result", block[:type]
    assert_equal "call_1", block[:tool_use_id]
    assert_equal "a tavern", block[:content]
  end

  def test_to_tools_builds_input_schema
    tools = {
      "move" => Boukensha::Tool.new("move", "Move in a direction.", {direction: {type: "string"}}, -> {})
    }
    result = @backend.to_tools(tools)

    assert_equal 1, result.size
    tool = result.first
    assert_equal "move", tool[:name]
    assert_equal "object", tool[:input_schema][:type]
    assert_equal({direction: {type: "string"}}, tool[:input_schema][:properties])
    assert_equal ["direction"], tool[:input_schema][:required]
  end

  def test_to_payload_shape
    payload = @backend.to_payload(system: "sys", messages: [], tools: [], max_output_tokens: 512)

    assert_equal "claude-haiku-4-5", payload[:model]
    assert_equal "sys", payload[:system]
    assert_equal 512, payload[:max_tokens]
    assert_equal [], payload[:tools]
    assert_equal [], payload[:messages]
  end

  def test_headers_include_api_key_and_version
    headers = @backend.headers
    assert_equal "fake-key", headers["x-api-key"]
    assert_equal "2023-06-01", headers["anthropic-version"]
  end

  def test_url
    assert_equal "https://api.anthropic.com/v1/messages", @backend.url
  end

  def test_parse_response_end_turn
    response = {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "hi"}]}
    parsed = @backend.parse_response(response)

    assert_equal "end_turn", parsed[:stop_reason]
    assert_equal [{"type" => "text", "text" => "hi"}], parsed[:content]
  end

  def test_parse_response_tool_use
    response = {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "name" => "look", "input" => {}}]}
    parsed = @backend.parse_response(response)

    assert_equal "tool_use", parsed[:stop_reason]
  end

  def test_parse_response_defaults_missing_content_to_empty_array
    parsed = @backend.parse_response({"stop_reason" => "end_turn"})
    assert_equal [], parsed[:content]
  end
end
