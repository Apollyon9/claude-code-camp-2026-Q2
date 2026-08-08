require_relative "test_helper"

class TestToolsMud < Minitest::Test
  class FakeSession
    attr_reader :sent_commands, :login_calls

    def initialize(responses: [])
      @responses = responses.dup
      @sent_commands = []
      @login_calls = []
      @open = false
    end

    def open? = @open
    def open = @open = true

    def login(name, password)
      @login_calls << [name, password]
      @open = true
    end

    def send_command(command)
      @sent_commands << command
    end

    def read_until_quiet(*)
      @responses.shift || "..."
    end
  end

  def setup
    @registry = Boukensha::Registry.new
    @session  = FakeSession.new(responses: ["a dimly lit tavern"])
    Boukensha::Tools::Mud.register(@registry, host: "localhost", port: 4000, name: "dummy", password: "helloworld", session: @session)
  end

  def test_registers_the_expected_tool_set
    expected = %w[look move check_self consider attack flee posture get_item drop_item give_item equip talk rest_recover shop]
    assert_equal expected.sort, @registry.tools.keys.sort
  end

  def test_look_dispatches_and_returns_output
    result = @registry.dispatch("look")
    assert_equal "a dimly lit tavern", result
  end

  def test_look_sends_a_look_command
    @registry.dispatch("look")
    assert_equal "look", @session.sent_commands.first.raw
  end

  def test_look_with_a_target
    @registry.dispatch("look", target: "chest")
    assert_equal "look chest", @session.sent_commands.first.raw
  end

  def test_move_sends_the_direction
    @registry.dispatch("move", direction: "north")
    assert_equal "north", @session.sent_commands.first.raw
  end

  def test_first_tool_call_connects_and_logs_in
    refute @session.open?
    @registry.dispatch("look")
    assert @session.open?
    assert_equal [["dummy", "helloworld"]], @session.login_calls
  end

  def test_session_is_only_opened_and_logged_in_once
    @session = FakeSession.new(responses: ["a", "b", "c"])
    Boukensha::Tools::Mud.register(@registry, host: "localhost", port: 4000, name: "dummy", password: "helloworld", session: @session)

    @registry.dispatch("look")
    @registry.dispatch("check_self", kind: "score")
    @registry.dispatch("move", direction: "north")

    assert_equal 1, @session.login_calls.size
  end

  def test_attack_sends_style_and_target
    @registry.dispatch("attack", style: "kill", target: "goblin")
    assert_equal "kill goblin", @session.sent_commands.first.raw
  end

  def test_talk_local_say
    @registry.dispatch("talk", mode: "say", text: "hello")
    assert_equal "say hello", @session.sent_commands.first.raw
  end

  def test_talk_targeted_tell_requires_target
    @registry.dispatch("talk", mode: "tell", text: "hi", target: "bob")
    assert_equal "tell bob hi", @session.sent_commands.first.raw
  end

  def test_equip_sends_op_and_object
    @registry.dispatch("equip", op: "wield", obj: "sword")
    assert_equal "wield sword", @session.sent_commands.first.raw
  end

  def test_get_item_with_container
    @registry.dispatch("get_item", obj: "gold", container: "chest")
    assert_equal "get gold chest", @session.sent_commands.first.raw
  end

  def test_flee_takes_no_arguments
    result = @registry.dispatch("flee")
    assert_equal "flee", @session.sent_commands.first.raw
    refute_nil result
  end

  def test_shop_list_reads_a_shopkeepers_wares
    @registry.dispatch("shop", op: "list")
    assert_equal "list", @session.sent_commands.first.raw
  end

  def test_shop_buy_with_an_item
    @registry.dispatch("shop", op: "buy", args: "bread")
    assert_equal "buy bread", @session.sent_commands.first.raw
  end
end
