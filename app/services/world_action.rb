class WorldAction
  class Invalid < StandardError; end

  def self.apply!(world:, action:, payload:)
    state = JSON.parse(world.game_state.to_json)
    messages = []

    case action
    when "move"
      direction = payload["direction"]
      player_room = state["player"]["room_id"]
      exits = state.dig("rooms", player_room, "exits") || {}

      unless exits.key?(direction)
        raise Invalid, "No exit '#{direction}' from current room"
      end

      new_room = exits[direction]
      state["player"]["room_id"] = new_room
      state["log"] << "You move #{direction} to #{new_room}."

    when "look"
      player_room = state["player"]["room_id"]
      room_data = state.dig("rooms", player_room) || {}
      desc = room_data["desc"] || "You see nothing special."
      items = room_data["items"] || []

      messages << desc
      if items.any?
        messages << "You see: #{items.join(', ')}"
      end
      state["log"] << "You look around."

    when "pickup"
      item = payload["item"]
      player_room = state["player"]["room_id"]
      room_items = state.dig("rooms", player_room, "items") || []

      unless room_items.include?(item)
        raise Invalid, "Item '#{item}' not found in current room"
      end

      state["rooms"][player_room]["items"].delete(item)
      state["player"]["inventory"] << item
      state["log"] << "You pick up #{item}."
      messages << "You pick up #{item}."

    else
      raise Invalid, "Invalid action: #{action}"
    end

    [ state, messages ]
  end
end
