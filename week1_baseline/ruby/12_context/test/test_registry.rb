require_relative "test_helper"

class TestRegistry < Minitest::Test
  def setup
    @registry = Boukensha::Registry.new
  end

  def test_starts_empty
    assert_equal 0, @registry.tool_count
    assert_equal({}, @registry.tools)
  end

  def test_tool_registers_and_returns_a_tool
    tool = @registry.tool("look", description: "Describe the room.") { "a tavern" }

    assert_kind_of Boukensha::Tool, tool
    assert_equal "look", tool.name
    assert_equal 1, @registry.tool_count
    assert_same tool, @registry.tools["look"]
  end

  def test_dispatch_calls_the_registered_block
    @registry.tool("look", description: "d") { "a tavern" }
    assert_equal "a tavern", @registry.dispatch("look")
  end

  def test_dispatch_passes_args_as_keywords
    @registry.tool("move", description: "d") { |direction:| "walked #{direction}" }
    assert_equal "walked north", @registry.dispatch("move", direction: "north")
  end

  def test_dispatch_symbolizes_string_keys
    @registry.tool("move", description: "d") { |direction:| "walked #{direction}" }
    assert_equal "walked north", @registry.dispatch("move", "direction" => "north")
  end

  def test_dispatch_accepts_a_symbol_name
    @registry.tool("look", description: "d") { "a tavern" }
    assert_equal "a tavern", @registry.dispatch(:look)
  end

  def test_dispatch_unknown_tool_raises
    error = assert_raises(Boukensha::UnknownToolError) { @registry.dispatch("attack") }
    assert_match(/attack/, error.message)
  end
end
