require_relative "test_helper"

class TestContext < Minitest::Test
  def test_defaults
    ctx = Boukensha::Context.new(system: "You are a MUD player agent.")
    assert_equal [], ctx.messages
    assert_equal 200_000, ctx.context_window
    assert_nil ctx.working_dir
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
  # README): Context must NOT hold tool storage. Registry owns it alone.
  def test_has_no_tools_field
    ctx = Boukensha::Context.new(system: "s")
    refute_respond_to ctx, :tools
  end

  def test_to_s_does_not_raise
    ctx = Boukensha::Context.new(system: "s")
    assert_kind_of String, ctx.to_s
  end
end
