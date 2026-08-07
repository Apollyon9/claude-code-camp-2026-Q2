require_relative "base"

module Boukensha
  module Tasks
    # The main loop: plays the MUD on the player's behalf. The only task
    # that exists in Week 1.
    class Player < Base
      def self.task_name = "player"
    end
  end
end
