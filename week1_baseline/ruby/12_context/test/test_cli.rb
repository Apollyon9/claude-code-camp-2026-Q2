require_relative "test_helper"
require "stringio"

class TestCli < Minitest::Test
  def test_version_flag_prints_version_and_touches_nothing_else
    output = StringIO.new
    ran = false
    cli = Boukensha::Cli.new(output: output, run_task: ->(_t) { ran = true }, start_repl: -> { ran = true })

    cli.call(["--version"])

    assert_includes output.string, Boukensha::VERSION
    refute ran
  end

  def test_short_version_flag
    output = StringIO.new
    cli = Boukensha::Cli.new(output: output, run_task: ->(_t) { "x" }, start_repl: -> {})

    cli.call(["-v"])

    assert_includes output.string, Boukensha::VERSION
  end

  def test_no_args_starts_the_repl_not_a_one_shot_run
    started = false
    cli = Boukensha::Cli.new(
      output: StringIO.new,
      run_task: ->(_t) { flunk "should not run a one-shot task" },
      start_repl: -> { started = true }
    )

    cli.call([])

    assert started
  end

  def test_args_join_into_one_task_and_print_the_result
    output = StringIO.new
    received_task = nil
    cli = Boukensha::Cli.new(
      output: output,
      run_task: ->(task) { received_task = task; "the result" },
      start_repl: -> { flunk "should not start the repl" }
    )

    cli.call(["find", "the", "bakery"])

    assert_equal "find the bakery", received_task
    assert_includes output.string, "the result"
  end
end
