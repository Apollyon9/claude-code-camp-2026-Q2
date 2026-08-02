module Boukensha
  module Tasks
    # A task is one role in the agentic loop, bound to its own provider and
    # model. Week 1 only drives a single task ("player", the main loop), but
    # the shape allows more later without changing how a task is configured.
    #
    # Tasks are stateless: every method takes the task's settings hash
    # (config.tasks(:player)) as an argument rather than holding it as
    # instance state, so there is never a question of which config a given
    # Task instance was built with.
    class Base
      def self.task_name
        raise NotImplementedError, "#{self} must define .task_name"
      end

      def self.provider(settings)
        settings["provider"] || settings[:provider] || "anthropic"
      end

      def self.model(settings)
        settings["model"] || settings[:model]
      end

      # Resolves this task's system prompt:
      #   1. .boukensha/prompts/<task_name>/system.md, when the task's
      #      prompt_override.system setting is true and the file exists.
      #   2. prompts/system.md, the default shipped with the library.
      def self.system_prompt(settings, user_prompts_dir:, default_prompts_dir:)
        if override_system?(settings)
          override_file = File.join(user_prompts_dir, task_name, "system.md")
          return File.read(override_file).strip if File.exist?(override_file)
        end

        default_file = File.join(default_prompts_dir, "system.md")
        File.exist?(default_file) ? File.read(default_file).strip : nil
      end

      def self.override_system?(settings)
        override = settings["prompt_override"] || settings[:prompt_override] || {}
        override["system"] || override[:system] || false
      end
    end
  end
end
