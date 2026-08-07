module Boukensha
  # The dispatch logic behind bin/boukensha, pulled into its own class so
  # argument parsing is testable without a live terminal or a real API call.
  # run_task:/start_repl: default to the real Boukensha.run/.repl, but are
  # injectable so a test can swap in a fake and assert on dispatch alone.
  class Cli
    def initialize(
      output: $stdout,
      run_task: ->(task) { Boukensha.run(task: task) },
      start_repl: -> { Boukensha.repl }
    )
      @output     = output
      @run_task   = run_task
      @start_repl = start_repl
    end

    def call(argv)
      if argv.include?("--version") || argv.include?("-v")
        @output.puts "boukensha #{VERSION}"
        return
      end

      if argv.empty?
        @start_repl.call
      else
        @output.puts @run_task.call(argv.join(" "))
      end
    end
  end
end
