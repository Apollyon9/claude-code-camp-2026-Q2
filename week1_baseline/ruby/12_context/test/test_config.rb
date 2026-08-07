require_relative "test_helper"

class TestConfig < Minitest::Test
  include ConfigTestHelper

  def test_raises_when_settings_file_missing
    Dir.mktmpdir do |dir|
      ENV["BOUKENSHA_DIR"] = dir
      assert_raises(Boukensha::ConfigError) { Boukensha::Config.new }
    ensure
      ENV.delete("BOUKENSHA_DIR")
    end
  end

  def test_resolves_dir_from_env_var
    with_config_dir(settings_yaml: "tasks: {}\n") do |dir|
      config = Boukensha::Config.new
      assert_equal File.realpath(dir), File.realpath(config.dir)
    end
  end

  def test_tasks_returns_full_hash_by_default
    with_config_dir(settings_yaml: <<~YAML) do
      tasks:
        player:
          provider: anthropic
          model: claude-haiku-4-5
      YAML
      config = Boukensha::Config.new
      assert_equal ["player"], config.tasks.keys
    end
  end

  def test_tasks_returns_single_task_hash_by_name
    with_config_dir(settings_yaml: <<~YAML) do
      tasks:
        player:
          provider: anthropic
      YAML
      config = Boukensha::Config.new
      assert_equal "anthropic", config.tasks(:player)["provider"]
    end
  end

  def test_tasks_returns_empty_hash_for_unknown_task
    with_config_dir(settings_yaml: "tasks: {}\n") do
      config = Boukensha::Config.new
      assert_equal({}, config.tasks(:nonexistent))
    end
  end

  def test_mud_settings_fall_back_to_defaults
    with_config_dir(settings_yaml: "tasks: {}\n") do
      config = Boukensha::Config.new
      assert_equal "localhost", config.mud_host
      assert_equal 4000, config.mud_port
      assert_nil config.mud_username
    end
  end

  def test_mud_settings_read_from_yaml
    with_config_dir(settings_yaml: <<~YAML) do
      tasks: {}
      mud:
        host: mud.example.com
        port: 5000
        username: dummy
      YAML
      config = Boukensha::Config.new
      assert_equal "mud.example.com", config.mud_host
      assert_equal 5000, config.mud_port
      assert_equal "dummy", config.mud_username
    end
  end

  def test_user_prompts_dir_is_scoped_to_config_dir
    with_config_dir(settings_yaml: "tasks: {}\n") do |dir|
      config = Boukensha::Config.new
      assert_equal File.join(dir, "prompts"), config.user_prompts_dir
    end
  end

  def test_env_file_is_loaded_into_env
    with_config_dir(settings_yaml: "tasks: {}\n", env: "SOME_TEST_KEY=abc123\n") do
      Boukensha::Config.new
      assert_equal "abc123", ENV["SOME_TEST_KEY"]
    ensure
      ENV.delete("SOME_TEST_KEY")
    end
  end
end
