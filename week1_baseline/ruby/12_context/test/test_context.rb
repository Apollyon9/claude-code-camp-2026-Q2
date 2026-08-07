require_relative "test_helper"

class TestContext < Minitest::Test
  def test_defaults
    ctx = Boukensha::Context.new(system: "You are a MUD player agent.")
    assert_equal [], ctx.messages
    assert_equal 200_000, ctx.context_window
    assert_nil ctx.working_dir
    assert_equal 0, ctx.current_tokens
    assert_equal 0, ctx.turn_tokens
    assert_in_delta 0.85, ctx.compaction_threshold, 0.001
  end

  def test_working_dir_is_settable
    ctx = Boukensha::Context.new(system: "s", working_dir: "/tmp")
    assert_equal "/tmp", ctx.working_dir
  end

  # Regression test for the mutable-default-argument trap (see step 01):
  # each Context must get its own messages array, not one shared default.
  def test_each_instance_gets_its_own_messages_array
    ctx_a = Boukensha::Context.new(system: "a")
    ctx_b = Boukensha::Context.new(system: "b")

    ctx_a.messages << Boukensha::Message.new(:user, "hello")

    assert_equal 1, ctx_a.messages.size
    assert_equal 0, ctx_b.messages.size
  end

  # Regression test for the deliberate divergence from the reference (see
  # step 02 README): Context must NOT hold tool storage. Registry owns it
  # alone.
  def test_has_no_tools_field
    ctx = Boukensha::Context.new(system: "s")
    refute_respond_to ctx, :tools
  end

  def test_to_s_does_not_raise
    ctx = Boukensha::Context.new(system: "s")
    assert_kind_of String, ctx.to_s
  end

  def test_update_tokens_sets_current_tokens
    ctx = Boukensha::Context.new(system: "s")
    ctx.update_tokens(5_000)
    assert_equal 5_000, ctx.current_tokens
  end

  def test_add_turn_tokens_accumulates
    ctx = Boukensha::Context.new(system: "s")
    ctx.add_turn_tokens(100, 50)
    ctx.add_turn_tokens(200, 25)
    assert_equal 375, ctx.turn_tokens
  end

  def test_reset_turn_tokens
    ctx = Boukensha::Context.new(system: "s")
    ctx.add_turn_tokens(100, 50)
    ctx.reset_turn_tokens
    assert_equal 0, ctx.turn_tokens
  end

  def test_usage_fraction_and_pct
    ctx = Boukensha::Context.new(system: "s", context_window: 1000)
    ctx.update_tokens(250)
    assert_in_delta 0.25, ctx.usage_fraction, 0.001
    assert_equal 25, ctx.usage_pct
  end

  def test_needs_compaction_below_threshold
    ctx = Boukensha::Context.new(system: "s", context_window: 1000, compaction_threshold: 0.8)
    ctx.update_tokens(700)
    refute ctx.needs_compaction?
  end

  def test_needs_compaction_at_or_above_threshold
    ctx = Boukensha::Context.new(system: "s", context_window: 1000, compaction_threshold: 0.8)
    ctx.update_tokens(800)
    assert ctx.needs_compaction?
  end

  def test_compact_messages_drops_oldest_and_keeps_at_least_two
    ctx = Boukensha::Context.new(system: "s")
    10.times { |i| ctx.messages << Boukensha::Message.new(:user, "msg #{i}") }
    ctx.update_tokens(9_999)

    dropped = ctx.compact_messages!

    assert_equal 4, dropped # 40% of 10
    assert_equal 6, ctx.messages.size
    assert_equal "msg 4", ctx.messages.first.content
    assert_equal 0, ctx.current_tokens
  end

  def test_compact_messages_never_drops_below_two
    ctx = Boukensha::Context.new(system: "s")
    ctx.messages << Boukensha::Message.new(:user, "a")
    ctx.messages << Boukensha::Message.new(:user, "b")

    dropped = ctx.compact_messages!

    assert_equal 0, dropped
    assert_equal 2, ctx.messages.size
  end

  def test_clear_messages_empties_history_and_resets_current_tokens
    ctx = Boukensha::Context.new(system: "s")
    ctx.messages << Boukensha::Message.new(:user, "hi")
    ctx.update_tokens(500)

    ctx.clear_messages!

    assert_empty ctx.messages
    assert_equal 0, ctx.current_tokens
  end
end
