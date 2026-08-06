require "yaml"
require "dotenv"
require "pathname"
require_relative "errors"

module Boukensha
  # Single source of truth for everything the agent needs to start: where its
  # config directory lives, what secrets it has, and what each task is
  # configured to do.
  class Config
    # Resolution order for the config directory:
    #   1. BOUKENSHA_DIR environment variable
    #   2. ~/.boukensha (default)
    DEFAULT_DIR = File.join(Dir.home, ".boukensha").freeze

    # Default prompts shipped with the library, used when a task has no
    # per-task override on disk.
    PROMPTS_DIR = File.expand_path("../../prompts", __dir__).freeze

    attr_reader :dir, :settings

    def initialize
      @dir = resolve_dir
      load_env
      @settings = load_settings
    end

    # Full tasks hash from settings.yaml, or a single task's hash by name.
    #   config.tasks           # => {"player" => {...}}
    #   config.tasks(:player)  # => {"provider" => "anthropic", ...}
    def tasks(name = nil)
      all = dig(:tasks) || {}
      name ? (all[name.to_s] || all[name.to_sym] || {}) : all
    end

    # Where a task's own prompt overrides live, e.g. .boukensha/prompts/player/
    def user_prompts_dir
      File.join(@dir, "prompts")
    end

    # ---------- MUD connection --------------------------------------------

    def mud_host     = dig(:mud, :host) || "localhost"
    def mud_port     = dig(:mud, :port) || 4000
    def mud_username = dig(:mud, :username)
    def mud_password = dig(:mud, :password)

    # ---------- low-level helpers -----------------------------------------

    # Fetch a nested key path from settings, e.g. dig(:mud, :host).
    # Settings load from YAML with string keys, but callers use symbols, so
    # both are checked at each level.
    def dig(*keys)
      keys.reduce(@settings) do |node, key|
        node.is_a?(Hash) ? (node[key.to_s] || node[key.to_sym]) : nil
      end
    end

    def to_s = "#<Boukensha::Config dir=#{@dir} tasks=#{tasks.keys.join(",")}>"
    def inspect = to_s

    private

    def resolve_dir
      Pathname.new(ENV.fetch("BOUKENSHA_DIR", DEFAULT_DIR)).expand_path.to_s
    end

    def load_env
      env_file = File.join(@dir, ".env")
      Dotenv.load(env_file) if File.exist?(env_file)
    end

    def load_settings
      settings_file = File.join(@dir, "settings.yaml")
      unless File.exist?(settings_file)
        raise ConfigError, "no settings.yaml found in #{@dir} " \
                            "(set BOUKENSHA_DIR to point elsewhere, or create one)"
      end

      YAML.safe_load(File.read(settings_file)) || {}
    end
  end
end
