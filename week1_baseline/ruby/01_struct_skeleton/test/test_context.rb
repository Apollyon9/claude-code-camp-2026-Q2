require_relative "test_helper"

class TestContext < Minitest::Test
  def test_defaults
    ctx = Boukensha::Context.new(system: "You are a MUD player agent.")
    assert_equal [], ctx.messages
    assert_equal({}, ctx.tools)
    assert_equal 200_000, ctx.context_window
    assert_nil ctx.working_dir
  end

  def test_working_dir_is_settable
    ctx = Boukensha::Context.new(system: "s", working_dir: "/tmp")
    assert_equal "/tmp", ctx.working_dir
  end

  # Regression test for the mutable-default-argument trap: a naive
  # `Struct.new(..., :messages)` with a default `[]` would share ONE array
  # across every instance, since the default is evaluated once, not per
  # instance. The keyword_init + overridden initialize pattern in
  # lib/boukensha/context.rb exists specifically to avoid this.
  def test_each_instance_gets_its_own_messages_array
    ctx_a = Boukensha::Context.new(system: "a")
    ctx_b = Boukensha::Context.new(system: "b")

    ctx_a.messages << Boukensha::Message.new(:user, "hello")

    assert_equal 1, ctx_a.messages.size
    assert_equal 0, ctx_b.messages.size
  end

  def test_each_instance_gets_its_own_tools_hash
    ctx_a = Boukensha::Context.new(system: "a")
    ctx_b = Boukensha::Context.new(system: "b")

    ctx_a.tools["look"] = Boukensha::Tool.new("look", "d", {}, -> {})

    assert_equal 1, ctx_a.tools.size
    assert_equal 0, ctx_b.tools.size
  end

  def test_to_s_does_not_raise
    ctx = Boukensha::Context.new(system: "s")
    assert_kind_of String, ctx.to_s
  end
end
