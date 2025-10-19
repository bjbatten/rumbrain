# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

def schema_path(name); Rails.root.join("docs", "schemas", "#{name}.schema.json"); end
def load_schema(name); JSONSchemer.schema(Pathname.new(schema_path(name))); end
def expect_json_schema!(payload, schema_name)
  errors = load_schema(schema_name).validate(payload).to_a
  expect(errors).to be_empty, "Schema #{schema_name} errors:\n#{errors.map(&:to_h)}"
end

RSpec.describe "Worlds NPC dialog (multi-turn)", type: :request do
  def json; JSON.parse(response.body); end
  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  it "records multi-turn conversation history per NPC and returns a reply" do
    wid = create_world

    # turn 1
    post "/worlds/#{wid}/npc/pirate_jeff/speak", params: { player_text: "hello there" }
    expect(response).to have_http_status(:ok)
    expect(json["npc_text"]).to be_a(String)
    expect_json_schema!(json["state"], "game_state")

    # turn 2 (memory should grow)
    post "/worlds/#{wid}/npc/pirate_jeff/speak", params: { player_text: "remember me?" }
    expect(response).to have_http_status(:ok)
    expect(json["npc_text"]).to be_a(String)
    state = json["state"]
    history = state.dig("npcs", "pirate_jeff", "dialog") || []
    expect(history.size).to be >= 2
    # Each entry should have role + text
    expect(history.last).to include("role", "text")

    # world remains schema-valid
    expect_json_schema!(state, "game_state")
  end

  it "caps remembered history length to 10 exchanges" do
    wid = create_world
    12.times do |i|
      post "/worlds/#{wid}/npc/pirate_jeff/speak", params: { player_text: "line #{i}" }
      expect(response).to have_http_status(:ok)
    end
    get "/worlds/#{wid}/state"
    state = json["state"]
    history = state.dig("npcs", "pirate_jeff", "dialog") || []
    expect(history.length).to be <= 10
  end

  it "400s if player_text blank" do
    wid = create_world
    post "/worlds/#{wid}/npc/pirate_jeff/speak", params: { player_text: "" }
    expect(response).to have_http_status(:bad_request)
  end
end
