require_relative "test_helper"
require "tmpdir"

class TestLogger < Minitest::Test
  def with_logger(**opts)
    Dir.mktmpdir do |dir|
      logger = Boukensha::Logger.new(dir: dir, **opts)
      yield logger, dir
    ensure
      logger&.close
    end
  end

  def read_events(path)
    File.readlines(path).map { |line| JSON.parse(line) }
  end

  def test_writes_one_file_per_session_under_dir
    with_logger do |logger, dir|
      assert_equal File.join(dir, "#{logger.session_id}.jsonl"), logger.path
      assert File.exist?(logger.path)
    end
  end

  def test_generates_a_session_id_when_none_given
    with_logger do |logger, _dir|
      refute_nil logger.session_id
      refute_empty logger.session_id
    end
  end

  def test_uses_a_given_session_id
    with_logger(session_id: "fixed-id") do |logger, dir|
      assert_equal "fixed-id", logger.session_id
      assert_equal File.join(dir, "fixed-id.jsonl"), logger.path
    end
  end

  def test_first_line_is_session_start_with_snapshot_merged_in
    with_logger(snapshot: {model: "claude-haiku-4-5", provider: "anthropic"}) do |logger, _dir|
      event = read_events(logger.path).first
      assert_equal "session_start", event["phase"]
      assert_equal "claude-haiku-4-5", event["model"]
      assert_equal "anthropic", event["provider"]
    end
  end

  def test_every_line_carries_session_id_and_timestamp
    with_logger do |logger, _dir|
      logger.iteration(n: 1, max: 25)
      event = read_events(logger.path).last
      assert_equal logger.session_id, event["session_id"]
      refute_nil event["at"]
    end
  end

  def test_iteration_event
    with_logger do |logger, _dir|
      logger.iteration(n: 3, max: 25)
      event = read_events(logger.path).last
      assert_equal "iteration", event["phase"]
      assert_equal 3, event["n"]
      assert_equal 25, event["max"]
    end
  end

  def test_tool_call_and_tool_result_events
    with_logger do |logger, _dir|
      logger.tool_call(name: "look", args: {})
      logger.tool_result(name: "look", result: "a tavern", ok: true)
      events = read_events(logger.path)

      call_event = events[-2]
      assert_equal "tool_call", call_event["phase"]
      assert_equal "look", call_event["name"]

      result_event = events[-1]
      assert_equal "tool_result", result_event["phase"]
      assert_equal "a tavern", result_event["result"]
      assert result_event["ok"]
    end
  end

  def test_tool_result_captures_failure
    with_logger do |logger, _dir|
      logger.tool_result(name: "attack", result: "ERROR: boom", ok: false, error: "boom")
      event = read_events(logger.path).last
      refute event["ok"]
      assert_equal "boom", event["error"]
    end
  end

  def test_response_event
    with_logger do |logger, _dir|
      logger.response(text: "  Hello!  ", stop_reason: "end_turn", cost: 0.000123)
      event = read_events(logger.path).last
      assert_equal "response", event["phase"]
      # text is stripped -- the log shouldn't preserve incidental whitespace.
      assert_equal "Hello!", event["text"]
      assert_equal "end_turn", event["stop_reason"]
      assert_in_delta 0.000123, event["cost"], 0.0000001
    end
  end

  def test_response_event_cost_defaults_to_nil
    with_logger do |logger, _dir|
      logger.response(text: "hi")
      event = read_events(logger.path).last
      assert_nil event["cost"]
    end
  end

  def test_limit_reached_and_turn_end_events
    with_logger do |logger, _dir|
      logger.limit_reached(kind: "max_iterations", n: 25, max: 25)
      logger.turn_end(reason: "max_iterations", iterations: 25)
      events = read_events(logger.path)

      assert_equal "limit_reached", events[-2]["phase"]
      assert_equal "turn_end", events[-1]["phase"]
      assert_equal "max_iterations", events[-1]["reason"]
    end
  end

  def test_turn_end_carries_tokens
    with_logger do |logger, _dir|
      logger.turn_end(reason: "completed", iterations: 3, tokens: 1234)
      event = read_events(logger.path).last
      assert_equal 1234, event["tokens"]
    end
  end

  def test_compaction_event
    with_logger do |logger, _dir|
      logger.compaction(before: 9000, dropped: 4, context_window: 10_000)
      event = read_events(logger.path).last
      assert_equal "compaction", event["phase"]
      assert_equal 9000, event["before"]
      assert_equal 4, event["dropped"]
      assert_equal 10_000, event["context_window"]
    end
  end

  def test_close_stops_further_writes_from_raising_but_file_stays_readable
    Dir.mktmpdir do |dir|
      logger = Boukensha::Logger.new(dir: dir)
      logger.iteration(n: 1, max: 25)
      logger.close
      assert_equal 2, read_events(logger.path).size # session_start + iteration
    end
  end
end
