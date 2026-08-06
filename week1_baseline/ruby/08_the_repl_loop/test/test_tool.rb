require_relative "test_helper"

class TestTool < Minitest::Test
  def test_holds_all_four_fields
    block = -> { "ok" }
    tool = Boukensha::Tool.new("look", "Describe the room.", {}, block)

    assert_equal "look", tool.name
    assert_equal "Describe the room.", tool.description
    assert_equal({}, tool.parameters)
    assert_equal block, tool.block
  end

  def test_to_s_does_not_raise
    tool = Boukensha::Tool.new("look", "d", {direction: {}}, -> {})
    assert_kind_of String, tool.to_s
  end
end
