class WorldsController < ApplicationController
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

    # Strongly permit game_action and payload parameters
    permitted_params = params.permit(:game_action, payload: {})
    game_action = permitted_params[:game_action]
    payload = permitted_params[:payload] || {}

    unless %w[move look pickup].include?(game_action)
      render json: { error: "invalid action" }, status: 400
      return
    end

    new_state, messages = WorldAction.apply!(world: world, action: game_action, payload: payload)
    world.update!(game_state: new_state)

    render json: WorldSerializer.render(world, messages: messages)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not found" }, status: 404
  rescue WorldAction::Invalid => e
    render json: { error: e.message }, status: 400
  rescue => e
    render json: { error: "Unexpected error: #{e.message}" }, status: 500
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
