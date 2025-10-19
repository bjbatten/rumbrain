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
      item = payload["item_id"] || payload["item"]
      player_room = state["player"]["room_id"]
      room_items = state.dig("rooms", player_room, "items") || []

      unless room_items.include?(item)
        raise Invalid, "Item '#{item}' not found in current room"
      end

      state["rooms"][player_room]["items"].delete(item)
      state["player"]["inventory"] << item
      state["log"] << "You picked up the #{item}."
      messages << "You picked up the #{item}."

  when "inventory"
      inventory = state["player"]["inventory"] || []
      if inventory.any?
        messages << "Your inventory: #{inventory.join(', ')}"
      else
        messages << "Your inventory is empty."
      end
  # game_state remains unchanged for inventory

  when "use"
      item = (payload["item_id"] || payload["item"]).to_s
      target = payload["target"].to_s
      raise Invalid, "item_id required" if item.empty?

      # Ensure containers exist
      state["flags"] ||= {}
      state["player"]["flags"] ||= {}
      state["player"]["flags"]["used_items"] ||= []
      inventory = state.dig("player", "inventory") || (state["player"]["inventory"] = [])
      unless inventory.include?(item)
        raise Invalid, "Item '#{item}' not in inventory"
      end

      # Remove item from inventory
      state["player"]["inventory"] = inventory - [ item ]
      state["player"]["flags"]["used_items"] << item

      # Door logic
      line = "You used the #{item}"
      if target == "door"
        state["flags"]["door_unlocked"] = true
        line += " on the door. It unlocks."
      elsif !target.empty?
        line += " on #{target}."
      else
        line += "."
      end
      messages << line
      state["log"] ||= []
      state["log"] << line

  else
      raise Invalid, "Invalid action: #{action}"
  end

    [ state, messages ]
  end
end
