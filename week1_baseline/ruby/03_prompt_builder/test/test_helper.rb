$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "minitest/autorun"
require "tmpdir"
require "boukensha"

# Points BOUKENSHA_DIR at a throwaway directory for the duration of a block,
# so Config tests never touch the real ~/.boukensha or the repo's own
# .boukensha. Restores the previous value afterward even if the block raises.
module ConfigTestHelper
  def with_config_dir(settings_yaml: nil, env: nil)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "settings.yaml"), settings_yaml) if settings_yaml
      File.write(File.join(dir, ".env"), env) if env

      previous = ENV["BOUKENSHA_DIR"]
      ENV["BOUKENSHA_DIR"] = dir
      begin
        yield dir
      ensure
        ENV["BOUKENSHA_DIR"] = previous
      end
    end
  end
end
