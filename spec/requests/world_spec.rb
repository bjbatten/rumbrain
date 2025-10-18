# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

# ---------------------------------------------------------------------------
# JSON schema helper
# ---------------------------------------------------------------------------
def schema_path(name)
  Rails.root.join("docs", "schemas", "#{name}.schema.json")
end

def load_schema(name)
  JSONSchemer.schema(Pathname.new(schema_path(name)))
end

def expect_json_schema!(payload, schema_name)
  schema = load_schema(schema_name)
  errors = schema.validate(payload).to_a
  expect(errors).to be_empty, "JSON schema validation failed for #{schema_name}:\n#{errors.map(&:to_h)}"
end

RSpec.describe "Worlds", type: :request do
  def json
    JSON.parse(response.body)
  end

  def expect_world_response!(body)
    expect(body).to include("world_id", "state", "messages")
    expect(body["world_id"]).to be_a(String)
    expect(body["messages"]).to be_a(Array)
    expect(body["state"]).to be_a(Hash) # state must be an object, not an array
  end

  def expect_game_state_shape!(state)
    expect(state).to include("player", "rooms", "npcs", "log")  # <-- fixed typo
    expect(state["rooms"].keys.size).to be_between(6, 9)
    expect(state["log"]).to be_a(Array)
  end

  describe "POST /worlds" do
    it "creates a world with deterministic state and valid schema" do
      post "/worlds", params: { seed: "banana", difficulty: "normal" }

      expect(response).to have_http_status(:created)
      expect_world_response!(json)

      game_state = json["state"]
      expect_game_state_shape!(game_state)
      expect_json_schema!(game_state, "game_state")
    end
  end

  describe "GET /worlds/:id/state" do
    it "returns the same world that was created" do
      post "/worlds", params: { seed: "banana" }
      world_id = json["world_id"]

      get "/worlds/#{world_id}/state"
      expect(response).to have_http_status(:ok)
      expect_world_response!(json)
      expect(json["world_id"]).to eq(world_id)
      expect_json_schema!(json["state"], "game_state")
    end
  end

  describe "POST /worlds/:id/act" do
    it "rejects invalid actions and leaves state unchanged" do
      post "/worlds", params: { seed: "banana" }
      world_id = json["world_id"]

      get "/worlds/#{world_id}/state"
      original_state = json["state"]

      post "/worlds/#{world_id}/act",
           params: { action: "teleport", payload: { room_id: "void" } }

      expect(response).to have_http_status(:bad_request)
      expect(json).to include("error")

      get "/worlds/#{world_id}/state"
      expect(json["state"]).to eq(original_state)
    end
  end
end
