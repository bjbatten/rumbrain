# frozen_string_literal: true

class PointClick
  class Invalid < StandardError; end

  # Returns:
  # - for non-talk ops: [new_state, messages]
  # - for talk:         [new_state, messages, npc_text]
  def self.apply!(world:, operation:, target:, text: nil)
    case operation
    when "walk"
      dir = target["id"].to_s
      raise Invalid, "missing exit id" if dir.empty?
      WorldAction.apply!(world: world, action: "move", payload: { "direction" => dir })

    when "look"
      # room/hotspot not needed for MVP; reuse WorldAction.look
      WorldAction.apply!(world: world, action: "look", payload: {})

    when "pickup"
      item_id = target["id"].to_s
      raise Invalid, "missing item id" if item_id.empty?
      WorldAction.apply!(world: world, action: "pickup", payload: { "item_id" => item_id })

    when "talk"
      npc_id = target["id"].to_s
      raise Invalid, "missing npc id" if npc_id.empty?
      # ensure NPC exists
      unless world.game_state.dig("npcs", npc_id)
        raise Invalid, "not found"
      end
      new_state, npc_text, messages = WorldSpeak.reply!(
        world: world, npc_id: npc_id, player_text: (text.presence || "hello")
      )
      [ new_state, messages, npc_text ]

    else
      raise Invalid, "invalid operation"
    end
  end
end
