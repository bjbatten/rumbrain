# frozen_string_literal: true

require "rails_helper"
def schema_path(name) = Rails.root.join("docs", "schemas", "game_state.schema.json")
require "json_schemer"

RSpec.describe "Worlds quest flags", type: :request do
  def json; JSON.parse(response.body); end
  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  it "sets a quest flag when player talks to Pirate Jeff holding a quest item" do
    wid = create_world

    # Walk to any room with an item, pick it up
    get "/worlds/#{wid}/state"
    state = json["state"]
    room_with_item = state["rooms"].detect { |_, r| (r["items"]||[]).any? }&.first
    raise "no items placed by procgen" unless room_with_item

    10.times do
      break if state["player"]["room_id"] == room_with_item
      post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
      expect(response).to have_http_status(:ok)
      get "/worlds/#{wid}/state"; state = json["state"]
    end
    item = state["rooms"][room_with_item]["items"].first
    post "/worlds/#{wid}/act", params: { game_action: "pickup", payload: { item_id: item } }
    expect(response).to have_http_status(:ok)

    # Walk to Pirate Jeff's room (room_3 in our procgen loop)
    10.times do
      break if state["player"]["room_id"] == "room_3"
      post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
      expect(response).to have_http_status(:ok)
      get "/worlds/#{wid}/state"; state = json["state"]
    end

    # Speak to Jeff to trigger the quest completion
    post "/worlds/#{wid}/npc/pirate_jeff/speak", params: { player_text: "I found this" }
    expect(response).to have_http_status(:ok)
    new_state = json["state"]
    expect_json_schema!(new_state)

  # Expect a quest flag
  flags = new_state["flags"] || {}
  expect(flags["quest_pirate_intro"]).to eq("completed")
    expect(json["messages"].join(" ")).to match(/quest|completed/i)
  end
end
