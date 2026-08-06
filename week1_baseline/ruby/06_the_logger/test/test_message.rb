require_relative "test_helper"

class TestMessage < Minitest::Test
  def test_holds_role_and_content
    msg = Boukensha::Message.new(:user, "look around")
    assert_equal :user, msg.role
    assert_equal "look around", msg.content
    assert_nil msg.tool_use_id
  end

  def test_tool_use_id_links_a_result_to_its_call
    msg = Boukensha::Message.new(:tool_result, "You see a tavern.", "call_1")
    assert_equal "call_1", msg.tool_use_id
  end

  def test_to_s_does_not_raise
    msg = Boukensha::Message.new(:assistant, "Looking around now.")
    assert_kind_of String, msg.to_s
  end
end
