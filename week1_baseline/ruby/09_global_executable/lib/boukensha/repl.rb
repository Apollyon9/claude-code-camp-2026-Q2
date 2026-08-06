module Boukensha
  # An interactive session that stays alive across turns. Reads a line,
  # either runs it as input to the agent or handles it as a command, prints
  # the reply, loops back to the prompt. input:/output: are injectable so
  # this can be driven from a script (or a test) as well as a real terminal.
  #
  # One Agent is built once and reused for every turn -- not rebuilt per
  # turn -- so it shares one Context (full history persists) across the
  # whole session. Agent#run resets its own iteration count at the start of
  # every call (see agent.rb), which is what makes reusing one instance safe.
  class Repl
    COMMANDS = %w[/clear /exit /quit /help].freeze

    def initialize(context:, registry:, builder:, client:, logger: NullLogger.new,
                   max_iterations: Agent::MAX_ITERATIONS, max_output_tokens: 1024,
                   input: $stdin, output: $stdout)
      @context = context
      @logger  = logger
      @input   = input
      @output  = output
      @agent = Agent.new(
        context: context, registry: registry, builder: builder, client: client, logger: logger,
        max_iterations: max_iterations, max_output_tokens: max_output_tokens
      )
    end

    def start
      @output.puts "Boukensha v#{VERSION} REPL. Type /help for commands, /exit to quit."
      loop do
        @output.print "> "
        line = @input.gets
        break if line.nil? # EOF, e.g. Ctrl+D

        line = line.strip
        next if line.empty?

        if line.start_with?("/")
          break if handle_command(line) == :exit
        else
          run_turn(line)
        end
      end
    ensure
      @logger.close
    end

    # Public so a caller (or a test) can drive one turn directly without
    # going through the blocking input loop in #start.
    def run_turn(input)
      @context.messages << Message.new(:user, input)
      result = @agent.run
      @output.puts result
      result
    end

    private

    def handle_command(line)
      case line
      when "/clear"
        @context.messages.clear
        @output.puts "History cleared."
        nil
      when "/exit", "/quit"
        @output.puts "Goodbye."
        :exit
      when "/help"
        @output.puts "Commands: #{COMMANDS.join(' ')}"
        nil
      else
        @output.puts "Unknown command: #{line} (try /help)"
        nil
      end
    end
  end
end
