require_relative "test_helper"

class TestPromptBuilder < Minitest::Test
  def setup
    @context  = Boukensha::Context.new(system: "You are a MUD player agent.")
    @registry = Boukensha::Registry.new
    @registry.tool("look", description: "Describe the room.") { "a tavern" }
    @backend = Boukensha::Backends::Anthropic.new(api_key: "fake-key", model: "claude-haiku-4-5")
    @builder = Boukensha::PromptBuilder.new(@context, @registry, @backend)
  end

  def test_to_messages_delegates_to_backend
    @context.messages << Boukensha::Message.new(:user, "look around")
    result = @builder.to_messages
    assert_equal [{role: "user", content: "look around"}], result
  end

  def test_to_tools_delegates_to_backend_with_registry_tools
    result = @builder.to_tools
    assert_equal 1, result.size
    assert_equal "look", result.first[:name]
  end

  def test_to_api_payload_assembles_system_messages_and_tools
    @context.messages << Boukensha::Message.new(:user, "look around")
    payload = @builder.to_api_payload(max_output_tokens: 256)

    assert_equal "You are a MUD player agent.", payload[:system]
    assert_equal 256, payload[:max_tokens]
    assert_equal 1, payload[:tools].size
    assert_equal 1, payload[:messages].size
  end

  def test_to_api_payload_tools_override_skips_registry_lookup
    payload = @builder.to_api_payload(tools: [])
    assert_equal [], payload[:tools]
  end

  def test_parse_response_delegates_to_backend
    parsed = @builder.parse_response({"stop_reason" => "end_turn", "content" => []})
    assert_equal "end_turn", parsed[:stop_reason]
  end

  def test_headers_and_url_delegate_to_backend
    assert_equal @backend.headers, @builder.headers
    assert_equal @backend.url, @builder.url
  end
end
