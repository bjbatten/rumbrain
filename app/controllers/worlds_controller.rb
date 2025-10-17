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

    render json: WorldSerializer.render(world, messages: ["World created."]), status: 201
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
    action = params[:action]
    
    unless %w[move look pickup use talk custom].include?(action)
      render json: { error: "invalid action" }, status: 400
      return
    end

    render json: WorldSerializer.render(world, messages: [])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not found" }, status: 404
  end
end