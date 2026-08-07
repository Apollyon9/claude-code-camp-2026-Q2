require_relative "test_helper"
require "stringio"

class TestRepl < Minitest::Test
  class FakeClient
    attr_reader :calls

    def initialize(responses)
      @responses = responses.dup
      @calls = []
    end

    def call(max_output_tokens:, tools: nil)
      @calls << {max_output_tokens: max_output_tokens, tools: tools}
      @responses.shift or raise "FakeClient ran out of queued responses"
    end

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

  def build_repl(responses, input_lines: [])
    client = FakeClient.new(responses)
    input  = StringIO.new(input_lines.join("\n") + "\n")
    output = StringIO.new
    repl = Boukensha::Repl.new(
      context: @context, registry: @registry, builder: @builder, client: client,
      max_iterations: 5, input: input, output: output
    )
    [repl, client, output]
  end

  def test_run_turn_returns_the_agents_final_text
    repl, = build_repl([{"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "Hello!"}]}])
    assert_equal "Hello!", repl.run_turn("hi")
  end

  def test_run_turn_appends_the_user_message_to_context
    repl, = build_repl([{"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "Hello!"}]}])
    repl.run_turn("hi there")
    assert_equal :user, @context.messages.first.role
    assert_equal "hi there", @context.messages.first.content
  end

  def test_context_persists_across_two_run_turn_calls
    repl, client = build_repl([{"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "first"}]}])
    repl.run_turn("turn one")

    client.enqueue({"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "second"}]})
    repl.run_turn("turn two")

    # Both user messages and both assistant replies are still in the shared
    # Context -- nothing got reset between turns.
    user_messages = @context.messages.select { |m| m.role == :user }
    assert_equal ["turn one", "turn two"], user_messages.map(&:content)
  end

  def test_second_turn_gets_a_fresh_iteration_budget_via_the_shared_agent
    tool_use = {"stop_reason" => "tool_use", "content" => [{"type" => "tool_use", "id" => "call_1", "name" => "look", "input" => {}}]}
    end_turn = {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "done"}]}

    # max_iterations: 5, first turn uses 2 -- if the shared Agent didn't
    # reset its count, the second turn would start already most of the way
    # to the ceiling instead of fresh.
    repl, client = build_repl([tool_use, end_turn])
    repl.run_turn("turn one")

    client.enqueue(tool_use, tool_use, tool_use, end_turn)
    result = repl.run_turn("turn two")
    assert_equal "done", result
  end

  def test_start_processes_scripted_input_until_eof
    responses = [{"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "Hello!"}]}]
    repl, _client, output = build_repl(responses, input_lines: ["hi"])
    repl.start
    assert_includes output.string, "Hello!"
  end

  def test_clear_command_empties_message_history
    repl, _client, output = build_repl([], input_lines: ["/clear", "/exit"])
    @context.messages << Boukensha::Message.new(:user, "leftover")
    repl.start
    assert_empty @context.messages
    assert_includes output.string, "History cleared."
  end

  def test_exit_command_stops_the_loop_without_needing_eof
    repl, client, output = build_repl([], input_lines: ["/exit", "this line should never be sent"])
    repl.start
    assert_includes output.string, "Goodbye."
    assert_empty client.calls
  end

  def test_unknown_command_does_not_crash_the_loop
    responses = [{"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "Hello!"}]}]
    repl, _client, output = build_repl(responses, input_lines: ["/nonsense", "hi"])
    repl.start
    assert_includes output.string, "Unknown command"
    assert_includes output.string, "Hello!"
  end

  def test_blank_lines_are_skipped
    responses = [{"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => "Hello!"}]}]
    repl, client, = build_repl(responses, input_lines: ["", "  ", "hi"])
    repl.start
    assert_equal 1, client.calls.size
  end
end
