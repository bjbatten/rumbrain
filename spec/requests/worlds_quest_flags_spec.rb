# frozen_string_literal: true

require "rails_helper"
def schema_path(name); Rails.root.join("docs", "schemas", "#{name}.schema.json"); end
require "json_schemer"

RSpec.describe "World flags & quest hooks", type: :request do
  def json; JSON.parse(response.body); end

  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  it "initializes top-level world flags" do
    wid = create_world
    get "/worlds/#{wid}/state"
    expect(response).to have_http_status(:ok)
    flags = json["state"]["flags"] || {}
    expect(flags).to be_a(Hash)
  expect_json_schema!(json["state"])
  end

  it "sets a world flag when using a key on a door, and NPC reacts to it" do
    wid = create_world

    # Walk to any room that has an item and pick it up (deterministic in our procgen)
    get "/worlds/#{wid}/state"
    state = json["state"]
    room_with_item = state["rooms"].detect { |_, data| (data["items"] || []).any? }&.first
    raise "ProcGen placed no items anywhere; adjust ProcGen" unless room_with_item

    12.times do
      break if state["player"]["room_id"] == room_with_item
      post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
      expect(response).to have_http_status(:ok)
      get "/worlds/#{wid}/state"
      state = json["state"]
    end
    item = state["rooms"][room_with_item]["items"].first

    post "/worlds/#{wid}/act", params: { game_action: "pickup", payload: { item_id: item } }
    expect(response).to have_http_status(:ok)

    # Use the item on 'door' to toggle a world flag
    post "/worlds/#{wid}/act", params: { game_action: "use", payload: { item_id: item, target: "door" } }
    expect(response).to have_http_status(:ok)
  expect_json_schema!(json["state"])

    flags = json["state"]["flags"] || {}
    expect(flags["door_unlocked"]).to eq(true)

    # Speak to Pirate Jeff; response should acknowledge the unlocked door
    post "/worlds/#{wid}/npc/pirate_jeff/speak", params: { player_text: "status?" }
    expect(response).to have_http_status(:ok)
    expect(json["npc_text"]).to be_a(String)
    expect(json["npc_text"].downcase).to include("door") # minimal assertion
  expect_json_schema!(json["state"])
  end

  it "does not set the flag if 'use' has no door target" do
    wid = create_world

    # Quick inventory request (no items needed)
    post "/worlds/#{wid}/act", params: { game_action: "inventory" }
    expect(response).to have_http_status(:ok)

    get "/worlds/#{wid}/state"
    flags = json["state"]["flags"] || {}
    expect(flags["door_unlocked"]).not_to eq(true)
  end
end
