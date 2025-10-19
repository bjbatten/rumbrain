class WorldSpeak
  class Invalid < StandardError; end

  def self.reply!(world:, npc_id:, player_text:)
  state = JSON.parse(world.game_state.to_json)

  # Nil-safe dialog array setup
  state["npcs"] ||= {}
  state["npcs"][npc_id] ||= {}
  state["npcs"][npc_id]["dialog"] ||= []
  dialog = state["npcs"][npc_id]["dialog"]

  # Append player message
  dialog << { "role" => "player", "text" => player_text }

  # Deterministic stub NPC reply
  mood = state["npcs"][npc_id]["mood"] || "neutral"
  npc_text = "(#{npc_id} in a #{mood} mood) You said: '#{player_text}'"

  # Append NPC reply
  dialog << { "role" => "npc", "text" => npc_text }

  # Trim dialog to last 10
  dialog.shift while dialog.size > 10

  # Always append log entry
  state["log"] << "You spoke with #{npc_id}."

  # Create message summary
  messages = [ "You converse with #{npc_id}." ]

  [ state, npc_text, messages ]
  end

  private

  def self.apply_patch!(state, patch)
    # Apply 'set' operations
    if patch["set"]
      patch["set"].each do |path, value|
        apply_set_path!(state, path, value)
      end
    end

    # Apply 'push' operations
    if patch["push"]
      patch["push"].each do |path, values|
        apply_push_path!(state, path, values)
      end
    end

    # Apply 'remove' operations
    if patch["remove"]
      patch["remove"].each do |path|
        apply_remove_path!(state, path)
      end
    end
  end

  def self.apply_set_path!(state, path, value)
    # Only allow safe paths under player, rooms, npcs, log
    return unless path_allowed?(path)

    parts = path.split(".")
    current = state

    # Navigate to parent
    parts[0..-2].each do |part|
      current[part] ||= {}
      current = current[part]
    end

    # Set final value
    current[parts.last] = value
  end

  def self.apply_push_path!(state, path, values)
    return unless path_allowed?(path)

    parts = path.split(".")
    current = state

    # Navigate to target array
    parts.each do |part|
      current = current[part]
      return unless current
    end

    # Push values if it's an array
    if current.is_a?(Array)
      Array(values).each { |v| current << v }
    end
  end

  def self.apply_remove_path!(state, path)
    return unless path_allowed?(path)

    # Only allow top-level removal for safety
    state.delete(path) if [ "player", "rooms", "npcs", "log" ].include?(path)
  end

  def self.path_allowed?(path)
    allowed_prefixes = [ "player", "rooms", "npcs", "log" ]
    allowed_prefixes.any? { |prefix| path.start_with?(prefix) }
  end
end
