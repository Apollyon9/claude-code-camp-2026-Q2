require_relative "test_helper"

class TestTasksBase < Minitest::Test
  def test_provider_defaults_to_anthropic
    assert_equal "anthropic", Boukensha::Tasks::Base.provider({})
  end

  def test_provider_reads_string_or_symbol_key
    assert_equal "openai", Boukensha::Tasks::Base.provider({"provider" => "openai"})
    assert_equal "openai", Boukensha::Tasks::Base.provider({provider: "openai"})
  end

  def test_model_has_no_default
    assert_nil Boukensha::Tasks::Base.model({})
  end

  def test_model_reads_string_or_symbol_key
    assert_equal "claude-haiku-4-5", Boukensha::Tasks::Base.model({"model" => "claude-haiku-4-5"})
    assert_equal "claude-haiku-4-5", Boukensha::Tasks::Base.model({model: "claude-haiku-4-5"})
  end

  def test_override_system_defaults_to_false
    refute Boukensha::Tasks::Base.override_system?({})
  end

  def test_override_system_reads_nested_key
    settings = {"prompt_override" => {"system" => true}}
    assert Boukensha::Tasks::Base.override_system?(settings)
  end

  def test_task_name_raises_on_base
    assert_raises(NotImplementedError) { Boukensha::Tasks::Base.task_name }
  end

  def test_system_prompt_falls_back_to_default_file
    Dir.mktmpdir do |default_dir|
      File.write(File.join(default_dir, "system.md"), "You are a MUD player agent.")

      prompt = Boukensha::Tasks::Player.system_prompt(
        {},
        user_prompts_dir: "/nonexistent",
        default_prompts_dir: default_dir
      )
      assert_equal "You are a MUD player agent.", prompt
    end
  end

  def test_system_prompt_uses_task_override_when_enabled_and_present
    Dir.mktmpdir do |user_dir|
      Dir.mktmpdir do |default_dir|
        File.write(File.join(default_dir, "system.md"), "default prompt")
        override_dir = File.join(user_dir, "player")
        Dir.mkdir(override_dir)
        File.write(File.join(override_dir, "system.md"), "override prompt")

        settings = {"prompt_override" => {"system" => true}}
        prompt = Boukensha::Tasks::Player.system_prompt(
          settings,
          user_prompts_dir: user_dir,
          default_prompts_dir: default_dir
        )
        assert_equal "override prompt", prompt
      end
    end
  end

  def test_system_prompt_returns_nil_when_no_files_exist
    Dir.mktmpdir do |default_dir|
      prompt = Boukensha::Tasks::Player.system_prompt(
        {},
        user_prompts_dir: "/nonexistent",
        default_prompts_dir: default_dir
      )
      assert_nil prompt
    end
  end
end

class TestTasksPlayer < Minitest::Test
  def test_task_name
    assert_equal "player", Boukensha::Tasks::Player.task_name
  end
end
