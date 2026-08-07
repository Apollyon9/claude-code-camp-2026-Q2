require_relative "lib/boukensha/version"

Gem::Specification.new do |spec|
  spec.name        = "boukensha"
  spec.version     = Boukensha::VERSION
  spec.summary     = "A baseline MUD-playing agent, built without an agent SDK."
  spec.authors     = ["Apollyon9"]
  spec.email       = ["100301199+Apollyon9@users.noreply.github.com"]
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.files       = Dir["lib/**/*.rb", "prompts/**/*.md", "bin/*"]
  spec.bindir      = "bin"
  spec.executables = ["boukensha"]
  spec.require_paths = ["lib"]

  spec.add_dependency "dotenv", "~> 3.1"
  spec.add_dependency "mud_manager", "~> 0.1"
end
