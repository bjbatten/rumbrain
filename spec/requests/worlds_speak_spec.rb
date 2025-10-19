# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

RSpec.describe "Worlds /speak", type: :request do
  def json; JSON.parse(response.body); end

  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  it "replies with NPC text and applies a valid state_patch" do
    wid = create_world
    # Pirate Jeff is guaranteed at room_3; put player there
    10.times do
      get "/worlds/#{wid}/state"
      break if json["state"]["player"]["room_id"] == "room_3"
      post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
      expect(response).to have_http_status(:ok)
    end

    post "/worlds/#{wid}/npc/pirate_jeff/speak", params: { player_text: "hello" }
    expect(response).to have_http_status(:ok)
    expect(json).to include("npc_text", "messages", "state")
    expect(json["npc_text"]).to be_a(String)
  expect_json_schema!(json["state"])

    # If a patch was returned and applied, it should persist
    get "/worlds/#{wid}/state"
  expect_json_schema!(json["state"])
  end

  it "404s for unknown NPC" do
    wid = create_world
    post "/worlds/#{wid}/npc/not_a_real_guy/speak", params: { player_text: "hello" }
    expect(response).to have_http_status(:not_found)
    expect(json).to include("error")
  end

  it "400s if player_text missing" do
    wid = create_world
    post "/worlds/#{wid}/npc/pirate_jeff/speak", params: {}
    expect(response).to have_http_status(:bad_request)
    expect(json).to include("error")
  end
end
