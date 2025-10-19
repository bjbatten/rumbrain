# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

RSpec.describe "Worlds /inventory & /pickup", type: :request do
  def json; JSON.parse(response.body); end

  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  it "lets the player pick up an item from the room" do
    wid = create_world

    # Get initial state
    get "/worlds/#{wid}/state"
    expect(response).to have_http_status(:ok)
    state = json["state"]

    # Find a room with at least one item
    room_with_item = state["rooms"].detect { |_, data| (data["items"] || []).any? }&.first
    if room_with_item.nil?
      raise "ProcGen placed no items anywhere; adjust ProcGen or seed"
    end

    # Walk along 'next' exits until we're in that room
    10.times do
      break if state["player"]["room_id"] == room_with_item
      post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
      expect(response).to have_http_status(:ok)
      get "/worlds/#{wid}/state"
      state = json["state"]
    end

    expect(state["player"]["room_id"]).to eq(room_with_item), "Failed to reach #{room_with_item}"

    item = state["rooms"][room_with_item]["items"].first
    post "/worlds/#{wid}/act", params: { game_action: "pickup", payload: { item_id: item } }
    expect(response).to have_http_status(:ok)
    expect(json["messages"].join).to match(/picked up/i)
    expect_json_schema!(json["state"], "game_state")

    new_state = json["state"]
    expect(new_state["player"]["inventory"]).to include(item)
    expect(new_state["rooms"][room_with_item]["items"]).not_to include(item)
  end


  it "returns the player inventory when requested" do
    wid = create_world

    post "/worlds/#{wid}/act",
         params: { game_action: "inventory" }

    expect(response).to have_http_status(:ok)
    expect(json["messages"].join).to match(/inventory/i)
    expect_json_schema!(json["state"], "game_state")
  end

  it "returns 400 when trying to pick up a nonexistent item" do
    wid = create_world
    post "/worlds/#{wid}/act",
         params: { game_action: "pickup", payload: { item_id: "ghost_item" } }

    expect(response).to have_http_status(:bad_request)
    expect(json).to include("error")
  end
end
