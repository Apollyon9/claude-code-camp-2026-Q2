require "mud_manager"

module Boukensha
  module Tools
    # Registers a grouped set of MUD gameplay tools backed by one persistent
    # MudManager::Session. The session connects and logs in lazily, on the
    # first tool call, not at registration time -- connection/login are
    # deterministic framework concerns, not something the agent decides to
    # do, so there is no "connect" or "login" tool for it to call or forget
    # to call.
    #
    # This groups MudManager's ~50 raw primitives into a smaller set of
    # purposeful tools (movement, combat, perception, inventory, equipment,
    # communication, posture) rather than a near 1:1 wrapper. The instructor
    # calls his own 1:1 mapping "a little bit undercooked" -- see README.
    module Mud
      module_function

      def register(registry, host:, port:, name:, password:, session: nil)
        session ||= MudManager::Session.new(host: host, port: port)
        connector = Connector.new(session, name, password)

        registry.tool("look", description: "Look at the room, or examine a specific object/direction.",
                      parameters: {target: {type: "string", description: "optional: something in the room to look at"}}) do |target: nil|
          send_and_read(connector, MudManager::Primitives.look(target: target))
        end

        registry.tool("move", description: "Move one step in a direction.",
                      parameters: {direction: {type: "string", enum: MudManager::Primitives::DIRECTIONS}}) do |direction:|
          send_and_read(connector, MudManager::Primitives.move(direction))
        end

        registry.tool("check_self", description: "Check your own status.",
                      parameters: {kind: {type: "string", enum: MudManager::Primitives::INFO_SELF}}) do |kind:|
          send_and_read(connector, MudManager::Primitives.info_self(kind))
        end

        registry.tool("consider", description: "Assess how dangerous a target looks before fighting it.",
                      parameters: {target: {type: "string"}}) do |target:|
          send_and_read(connector, MudManager::Primitives.consider(target))
        end

        registry.tool("attack", description: "Attack a target.",
                      parameters: {
                        style: {type: "string", enum: MudManager::Primitives::ATTACK_STYLES},
                        target: {type: "string"}
                      }) do |style:, target:|
          send_and_read(connector, MudManager::Primitives.attack(style, target))
        end

        registry.tool("flee", description: "Flee combat in a random direction.") do
          send_and_read(connector, MudManager::Primitives.flee)
        end

        registry.tool("posture", description: "Change your position (stand, sit, rest, sleep, wake).",
                      parameters: {pos: {type: "string", enum: MudManager::Primitives::POSITIONS}}) do |pos:|
          send_and_read(connector, MudManager::Primitives.set_position(pos))
        end

        registry.tool("get_item", description: "Pick up an item from the room or a container.",
                      parameters: {
                        obj: {type: "string"},
                        container: {type: "string", description: "optional: container to get it from"}
                      }) do |obj:, container: nil|
          send_and_read(connector, MudManager::Primitives.get(obj, container: container))
        end

        registry.tool("drop_item", description: "Drop, donate, or junk an item.",
                      parameters: {
                        mode: {type: "string", enum: MudManager::Primitives::DROP_MODES},
                        obj: {type: "string"}
                      }) do |mode:, obj:|
          send_and_read(connector, MudManager::Primitives.drop(mode, obj))
        end

        registry.tool("give_item", description: "Give an item to another character.",
                      parameters: {obj: {type: "string"}, target: {type: "string"}}) do |obj:, target:|
          send_and_read(connector, MudManager::Primitives.give(obj, target))
        end

        registry.tool("equip", description: "Wear, wield, or remove an item.",
                      parameters: {
                        op: {type: "string", enum: MudManager::Primitives::EQUIP_OPS},
                        obj: {type: "string"}
                      }) do |op:, obj:|
          send_and_read(connector, MudManager::Primitives.equip(op, obj))
        end

        registry.tool("talk", description: "Say, emote, tell, or ask something.",
                      parameters: {
                        mode: {type: "string", enum: MudManager::Primitives::LOCAL_SAY + MudManager::Primitives::TARGETED_SAY},
                        text: {type: "string"},
                        target: {type: "string", description: "required for tell/whisper/ask"}
                      }) do |mode:, text:, target: nil|
          command = if MudManager::Primitives::TARGETED_SAY.include?(mode.to_s.downcase)
                      MudManager::Primitives.say_targeted(mode, target, text)
                    else
                      MudManager::Primitives.say_local(mode, text)
                    end
          send_and_read(connector, command)
        end

        registry.tool("rest_recover", description: "Save your character to disk.") do
          send_and_read(connector, MudManager::Primitives.save_char)
        end
      end

      # Ensures the session is open and logged in exactly once, on the first
      # call, and reused for every tool call after that.
      class Connector
        def initialize(session, name, password)
          @session  = session
          @name     = name
          @password = password
          @logged_in = false
        end

        def ensure_connected!
          return if @logged_in

          @session.open unless @session.open?
          @session.login(@name, @password)
          @logged_in = true
        end

        def send_command(command)
          @session.send_command(command)
        end

        def read_until_quiet(*args)
          @session.read_until_quiet(*args)
        end
      end
      private_constant :Connector

      def send_and_read(connector, command)
        connector.ensure_connected!
        connector.send_command(command)
        connector.read_until_quiet
      end
      private_class_method :send_and_read
    end
  end
end
