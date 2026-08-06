require_relative "test_helper"

class TestRunDSL < Minitest::Test
  def test_tool_registers_into_the_registry
    registry = Boukensha::Registry.new
    dsl = Boukensha::RunDSL.new(registry)

    dsl.tool("look", description: "d") { "a tavern" }

    assert_equal 1, registry.tool_count
    assert_equal "look", registry.tools["look"].name
  end

  def test_tool_returns_what_registry_tool_returns
    registry = Boukensha::Registry.new
    dsl = Boukensha::RunDSL.new(registry)

    result = dsl.tool("look", description: "d") { "a tavern" }

    assert_kind_of Boukensha::Tool, result
  end
end
