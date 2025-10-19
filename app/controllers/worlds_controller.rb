class WorldsController < ApplicationController
  ALLOWED_ACTIONS = %w[move look pickup inventory use walk talk].freeze
  def create
    seed = params[:seed]
    difficulty = params[:difficulty] || "normal"

    if seed.blank?
      render json: { error: "seed is required" }, status: 422
      return
    end

    game_state = ProcGen.build(seed: seed, difficulty: difficulty)
    world = World.create!(seed: seed, difficulty: difficulty, game_state: game_state)

    render json: WorldSerializer.render(world, messages: [ "World created." ]), status: 201
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: 422
  end

  def state
    world = World.find(params[:id])
    render json: WorldSerializer.render(world, messages: [])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not found" }, status: 404
  end

  def act
    world = World.find(params[:id])
    permitted_params = params.permit(:game_action, payload: {})
    game_action = permitted_params[:game_action]
    payload = permitted_params[:payload] || {}

    unless ALLOWED_ACTIONS.include?(game_action)
      render json: { error: "invalid action" }, status: 400
      return
    end

    if game_action == "talk"
      npc_id = payload["npc_id"]
      player_text = payload["player_text"]
      unless npc_id && player_text
        render json: { error: "npc_id and player_text required for talk" }, status: 400
        return
      end
      new_state, npc_text, messages = WorldSpeak.reply!(world: world, npc_id: npc_id, player_text: player_text)
      world.update!(game_state: new_state)
      effects = [ { "type" => "say", "npc_id" => npc_id, "text" => npc_text } ]
      render json: WorldSerializer.render(world, messages: messages, effects: effects)
    else
      new_state, messages, effects = WorldAction.apply!(world: world, action: game_action, payload: payload)
      world.update!(game_state: new_state)
      render json: WorldSerializer.render(world, messages: messages, effects: effects)
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not found" }, status: 404
  rescue WorldAction::Invalid => e
    render json: { error: e.message }, status: 400
  rescue => e
    render json: { error: "Unexpected error: #{e.message}" }, status: 500
  end
  def scene
    world = World.find(params[:id])
    player_room = world.game_state.dig("player", "room_id")
    room = world.game_state.dig("rooms", player_room) || {}
    scene = room["scene"]&.dup || {}
    # Convert hotspots and exits from Hash to Array if present
    if scene["hotspots"].is_a?(Hash)
      scene["hotspots"] = scene["hotspots"].values
    end
    if scene["exits"].is_a?(Hash)
      scene["exits"] = scene["exits"].values
    end
    bundle = {
      "room_id" => player_room,
      "scene" => scene,
      "npcs" => world.game_state["npcs"],
      "items" => room["items"]
    }
    render json: { world_id: world.id, bundle: bundle, messages: [] }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not found" }, status: 404
  end

  def resume
    code = params[:code].to_s.strip
    world = World.find_by(save_code: code)
    if world
      render json: WorldSerializer.render(world, messages: [ "World resumed." ]), status: :ok
    else
      render json: { error: "not found" }, status: :not_found
    end
  end

  def resume_link
    code = params[:code].to_s.strip.downcase
    world = World.find_by(save_code: code)
    if world
      render json: WorldSerializer.render(world, messages: [ "World resumed via link." ]), status: :ok
    else
      render json: { error: "not found" }, status: :not_found
    end
  end


  def speak
    world = World.find(params[:id])
    npc_id = params[:npc_id]
    player_text = params[:player_text]

    # Check if NPC exists in the world
    unless world.game_state.dig("npcs", npc_id)
      render json: { error: "not found" }, status: 404
      return
    end

    # Require player_text parameter
    if player_text.blank?
      render json: { error: "player_text is required" }, status: 400
      return
    end

    new_state, npc_text, messages = WorldSpeak.reply!(world: world, npc_id: npc_id, player_text: player_text)
    world.update!(game_state: new_state)

    render json: { npc_text: npc_text, state: new_state, messages: messages }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not found" }, status: 404
  rescue WorldSpeak::Invalid => e
    render json: { error: e.message }, status: 400
  rescue => e
    render json: { error: "Unexpected error: #{e.message}" }, status: 500
  end
end
