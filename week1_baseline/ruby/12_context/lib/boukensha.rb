require_relative "boukensha/version"
require_relative "boukensha/errors"
require_relative "boukensha/config"
require_relative "boukensha/tasks/base"
require_relative "boukensha/tasks/player"
require_relative "boukensha/tool"
require_relative "boukensha/message"
require_relative "boukensha/models"
require_relative "boukensha/context"
require_relative "boukensha/registry"
require_relative "boukensha/backends/base"
require_relative "boukensha/backends/anthropic"
require_relative "boukensha/prompt_builder"
require_relative "boukensha/client"
require_relative "boukensha/logger"
require_relative "boukensha/null_logger"
require_relative "boukensha/agent"
require_relative "boukensha/run_dsl"
require_relative "boukensha/repl"
require_relative "boukensha/cli"
require_relative "boukensha/tools/mud"

module Boukensha
  # One-shot run: send a single task to the player agent, get a response,
  # return. Wraps everything examples/example.rb has been wiring up by hand
  # since step 00 -- Config, Context, Registry, backend, PromptBuilder,
  # Client, Logger, Agent -- behind one call, the way an SDK would.
  #
  # tools are registered inline via the block, evaluated as a RunDSL:
  #   Boukensha.run(task: "look around") do
  #     tool("look", description: "...") { "a tavern" }
  #   end
  def self.run(
    task:,
    system: nil,
    model: nil,
    backend: nil,
    api_key: nil,
    max_iterations: nil,
    max_turn_tokens: nil,
    max_output_tokens: 1024,
    context_window: nil,
    log: true,
    mud: nil,
    &block
  )
    context, registry, builder, client, logger = build_stack(
      system: system, model: model, backend: backend, api_key: api_key, log: log, mud: mud,
      context_window: context_window, &block
    )
    agent = Agent.new(
      context: context, registry: registry, builder: builder, client: client, logger: logger,
      max_iterations: max_iterations || Agent::MAX_ITERATIONS, max_turn_tokens: max_turn_tokens,
      max_output_tokens: max_output_tokens
    )

    context.messages << Message.new(:user, task)
    agent.run
  ensure
    logger&.close
  end

  # Interactive REPL -- same setup and same settings.yaml resolution as
  # .run, but stays alive across turns instead of returning after one. See
  # Repl for the loop itself.
  def self.repl(
    system: nil,
    model: nil,
    backend: nil,
    api_key: nil,
    max_iterations: nil,
    max_turn_tokens: nil,
    max_output_tokens: 1024,
    context_window: nil,
    log: true,
    mud: nil,
    &block
  )
    context, registry, builder, client, logger = build_stack(
      system: system, model: model, backend: backend, api_key: api_key, log: log, mud: mud,
      context_window: context_window, &block
    )
    Repl.new(
      context: context, registry: registry, builder: builder, client: client, logger: logger,
      max_iterations: max_iterations || Agent::MAX_ITERATIONS, max_turn_tokens: max_turn_tokens,
      max_output_tokens: max_output_tokens
    ).start
  end

  # Shared by .run and .repl: resolves provider/model/system prompt from
  # settings.yaml's tasks.player block via Tasks::Player (any of them
  # overridable per call), builds Context/Registry/backend/PromptBuilder/
  # Client/Logger, and evaluates the tool-registration block as a RunDSL.
  def self.build_stack(system:, model:, backend:, api_key:, log:, mud:, context_window:, &block)
    config   = Config.new
    settings = config.tasks(:player)

    system ||= Tasks::Player.system_prompt(
      settings,
      user_prompts_dir: config.user_prompts_dir,
      default_prompts_dir: Config::PROMPTS_DIR
    )
    model ||= Tasks::Player.model(settings)
    raise ConfigError, "no model configured (settings.yaml tasks.player.model, or pass model:)" unless model

    backend_name = (backend || Tasks::Player.provider(settings)).to_sym
    api_key    ||= ENV["ANTHROPIC_API_KEY"]
    context_window ||= Models.context_window(model)

    context  = Context.new(system: system, context_window: context_window)
    registry = Registry.new

    # mud: nil means "use settings.yaml if a host is configured", mud: false
    # means "skip entirely", a Hash overrides config outright.
    resolved_mud = mud == false ? nil : (mud || mud_opts_from_config(config))
    Tools::Mud.register(registry, **resolved_mud) if resolved_mud

    RunDSL.new(registry).instance_eval(&block) if block

    be = case backend_name
         when :anthropic then Backends::Anthropic.new(api_key: api_key, model: model)
         else raise ArgumentError, "Unknown backend #{backend_name.inspect}. Only :anthropic is supported so far."
         end

    builder = PromptBuilder.new(context, registry, be)
    client  = Client.new(builder)
    logger  = log ? Logger.new(dir: File.join(config.dir, "sessions"), snapshot: {provider: backend_name, model: model}) : NullLogger.new

    [context, registry, builder, client, logger]
  end
  private_class_method :build_stack

  def self.mud_opts_from_config(config)
    return nil unless config.mud_host && config.mud_username

    {host: config.mud_host, port: config.mud_port, name: config.mud_username, password: config.mud_password}
  end
  private_class_method :mud_opts_from_config
end
