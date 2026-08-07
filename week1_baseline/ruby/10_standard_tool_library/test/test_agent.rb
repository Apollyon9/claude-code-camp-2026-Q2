require_relative "test_helper"

class TestAgent < Minitest::Test
  # Only the network boundary is faked. parse_response still runs through
  # the real PromptBuilder + Backends::Anthropic, already covered by their
  # own tests, so a queued response here is raw Anthropic JSON shape.
  class FakeClient
    attr_reader :calls

    def initialize(responses)
      @responses = responses.dup
      @calls = []
    end

    def call(max_output_tokens:, tools: nil)
      @calls << {max_output_tokens: max_output_tokens, tools: tools}
      response = @responses.shift or raise "FakeClient ran out of queued responses"
      raise Boukensha::ApiError, "simulated failure" if response == :raise_api_error

      response
    end

    # Lets a test queue up a second turn's worth of responses after the
    # first turn already ran, for scenarios that reuse one Agent/Client
    # across multiple #run calls.
    def enqueue(*responses)
      @responses.concat(responses)
    end
  end

  def setup
    @context  = Boukensha::Context.new(system: "You are a MUD player agent.")
    @registry = Boukensha::Registry.new
    @registry.tool("look", description: "d") { "a dimly lit tavern" }
    backend  = Boukensha::Backends::Anthropic.new(api_key: "fake-key", model: "claude-haiku-4-5")
    @builder = Boukensha::PromptBuilder.new(@context, @registry, backend)
  end

  # Records which logger methods were called and with what, without writing
  # anything to disk -- proves Agent actually logs, independent of whether
  # Logger itself formats JSONL correctly (that's test_logger.rb's job).
  class SpyLogger
    attr_reader :calls

    def initialize
      @calls = []
    end

    %i[iteration tool_call tool_result response limit_reached turn_end].each do |method|
      define_method(method) { |**kwargs| @calls << [method, kwargs] }
    end

    def close = nil
  end

  def build_agent(responses, **opts)
    client = FakeClient.new(responses)
    agent = Boukensha::Agent.new(context: @context, registry: @registry, builder: @builder, client: client, **opts)
    [agent, client]
  end

  def test_defaults_to_a_null_logger_that_touches_nothing
    responses = [{"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "hi"}]}]
    agent, = build_agent(responses)
    # No logger: passed at all -- this must not raise or touch the filesystem.
    assert_equal "hi", agent.run
  end

  def test_returns_text_on_immediate_end_turn
    responses = [{"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "Hello!"}]}]
    agent, client = build_agent(responses)

    result = agent.run

    assert_equal "Hello!", result
    assert_equal 1, client.calls.size
    assert_equal :assistant, @context.messages.last.role
    assert_equal "Hello!", @context.messages.last.content
  end

  def test_dispatches_a_tool_call_then_returns_final_text
    responses = [
      {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]},
      {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "You see a tavern."}]}
    ]
    agent, client = build_agent(responses)

    result = agent.run

    assert_equal "You see a tavern.", result
    assert_equal 2, client.calls.size

    tool_result = @context.messages.find { |m| m.role == :tool_result }
    assert_equal "a dimly lit tavern", tool_result.content
    assert_equal "call_1", tool_result.tool_use_id
  end

  def test_assistant_turn_records_the_full_content_including_tool_use_block
    responses = [
      {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]},
      {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "done"}]}
    ]
    agent, = build_agent(responses)
    agent.run

    assistant_turn = @context.messages.find { |m| m.role == :assistant && m.content.is_a?(Array) }
    assert_equal "tool_use", assistant_turn.content.first["type"]
  end

  def test_unknown_tool_becomes_an_error_result_instead_of_crashing
    responses = [
      {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "attack", "input" => {}}]},
      {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "ok"}]}
    ]
    agent, = build_agent(responses)

    result = agent.run

    assert_equal "ok", result
    tool_result = @context.messages.find { |m| m.role == :tool_result }
    assert_match(/^ERROR:.*UnknownToolError/, tool_result.content)
  end

  def test_wraps_up_when_max_iterations_reached
    tool_use = {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]}
    wrap_up_response = {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "Summary so far."}]}
    responses = [tool_use, tool_use, wrap_up_response]

    agent, client = build_agent(responses, max_iterations: 2)
    result = agent.run

    assert_equal "Summary so far.", result
    assert_equal 3, client.calls.size
    # The wrap-up call disables tools and uses its own smaller token budget.
    assert_equal [], client.calls.last[:tools]
    assert_equal Boukensha::Agent::WRAP_UP_OUTPUT_TOKENS, client.calls.last[:max_output_tokens]
  end

  def test_wrap_up_falls_back_to_a_fixed_message_if_the_wrap_up_call_fails
    tool_use = {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]}
    responses = [tool_use, :raise_api_error]

    agent, = build_agent(responses, max_iterations: 1)
    result = agent.run

    assert_match(/action limit/, result)
    assert_equal :assistant, @context.messages.last.role
  end

  def test_wrap_up_falls_back_when_the_model_returns_only_empty_text
    tool_use = {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]}
    empty_response = {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "   "}]}
    responses = [tool_use, empty_response]

    agent, = build_agent(responses, max_iterations: 1)
    result = agent.run

    assert_match(/action limit/, result)
  end

  def test_logs_iteration_tool_call_and_result_and_turn_end
    responses = [
      {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]},
      {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "done"}]}
    ]
    spy = SpyLogger.new
    client = FakeClient.new(responses)
    agent = Boukensha::Agent.new(context: @context, registry: @registry, builder: @builder, client: client, logger: spy)
    agent.run

    methods_called = spy.calls.map(&:first)
    assert_includes methods_called, :iteration
    assert_includes methods_called, :tool_call
    assert_includes methods_called, :tool_result
    assert_includes methods_called, :turn_end

    tool_call = spy.calls.find { |m, _| m == :tool_call }.last
    assert_equal "look", tool_call[:name]

    tool_result = spy.calls.find { |m, _| m == :tool_result }.last
    assert tool_result[:ok]

    turn_end = spy.calls.find { |m, _| m == :turn_end }.last
    assert_equal "completed", turn_end[:reason]
  end

  def test_logs_a_failed_tool_result
    responses = [
      {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "attack", "input" => {}}]},
      {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "ok"}]}
    ]
    spy = SpyLogger.new
    client = FakeClient.new(responses)
    agent = Boukensha::Agent.new(context: @context, registry: @registry, builder: @builder, client: client, logger: spy)
    agent.run

    tool_result = spy.calls.find { |m, _| m == :tool_result }.last
    refute tool_result[:ok]
    assert_match(/No tool registered as 'attack'/, tool_result[:error])
  end

  def test_logs_limit_reached_and_turn_end_on_wrap_up
    tool_use = {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]}
    wrap_up_response = {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "Summary."}]}
    spy = SpyLogger.new
    client = FakeClient.new([tool_use, wrap_up_response])
    agent = Boukensha::Agent.new(context: @context, registry: @registry, builder: @builder, client: client,
                                  logger: spy, max_iterations: 1)
    agent.run

    methods_called = spy.calls.map(&:first)
    assert_includes methods_called, :limit_reached

    turn_end = spy.calls.find { |m, _| m == :turn_end }.last
    assert_equal "max_iterations", turn_end[:reason]
  end

  # Regression test for reusing one Agent across multiple turns (see Repl,
  # step 08). Without resetting @iteration at the start of #run, a second
  # turn would inherit whatever count the first turn left behind and could
  # hit max_iterations immediately, even though the second turn just began.
  def test_a_single_agent_instance_gets_a_fresh_iteration_budget_each_run
    tool_use = {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]}
    end_turn = {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "done"}]}

    client = FakeClient.new([tool_use, tool_use, end_turn])
    agent = Boukensha::Agent.new(context: @context, registry: @registry, builder: @builder, client: client,
                                  max_iterations: 3)
    first_result = agent.run
    assert_equal "done", first_result
    assert_equal 3, client.calls.size

    # Second turn, same Agent instance, fresh queue of responses. If
    # @iteration carried over from the first turn (already at 3), this call
    # would immediately hit the ceiling and wrap up instead of running.
    client.enqueue(tool_use, end_turn)
    second_result = agent.run
    assert_equal "done", second_result
  end
end
