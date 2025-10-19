# spec/requests/worlds_use_spec.rb
# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

RSpec.describe "Worlds /act use", type: :request do
  def json; JSON.parse(response.body); end

  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  it "uses an item from inventory and records the effect" do
    wid = create_world

    # Find an item somewhere in the world, walk there, pick it up
    get "/worlds/#{wid}/state"
    state = json["state"]
    room_with_item = state["rooms"].detect { |_, data| (data["items"] || []).any? }&.first
    raise "ProcGen placed no items anywhere; adjust ProcGen" unless room_with_item

    10.times do
      break if state["player"]["room_id"] == room_with_item
      post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
      expect(response).to have_http_status(:ok)
      get "/worlds/#{wid}/state"
      state = json["state"]
    end
    item = state["rooms"][room_with_item]["items"].first

    post "/worlds/#{wid}/act", params: { game_action: "pickup", payload: { item_id: item } }
    expect(response).to have_http_status(:ok)

    # Now use it (optionally with a target)
    post "/worlds/#{wid}/act", params: { game_action: "use", payload: { item_id: item, target: "door" } }
    expect(response).to have_http_status(:ok)
    expect(json["messages"].join).to match(/use|used/i)

    # State stays schema-valid
    expect_json_schema!(json["state"], "game_state")

    # Item is no longer in inventory; a flag records the effect
    new_state = json["state"]
    expect(new_state["player"]["inventory"]).not_to include(item)
    flags = new_state["player"]["flags"] || {}
    expect(flags["used_items"]).to include(item)
  end

  it "400s when trying to use an item not in inventory" do
    wid = create_world
    post "/worlds/#{wid}/act", params: { game_action: "use", payload: { item_id: "ghost_item" } }
    expect(response).to have_http_status(:bad_request)
    expect(json).to include("error")
  end

  it "400s when item_id missing" do
    wid = create_world
    post "/worlds/#{wid}/act", params: { game_action: "use", payload: {} }
    expect(response).to have_http_status(:bad_request)
    expect(json).to include("error")
  end
end
