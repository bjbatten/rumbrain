# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

def schema_path(name); Rails.root.join("docs", "schemas", "#{name}.schema.json"); end
def load_schema(name); JSONSchemer.schema(Pathname.new(schema_path(name))); end
def expect_json_schema!(payload, schema_name)
  errors = load_schema(schema_name).validate(payload).to_a
  expect(errors).to be_empty, "Schema #{schema_name} errors:\n#{errors.map(&:to_h)}"
end

RSpec.describe "Worlds /scene", type: :request do
  def json; JSON.parse(response.body); end

  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  it "returns a scene bundle for the player's current room" do
    wid = create_world

    get "/worlds/#{wid}/scene"
    expect(response).to have_http_status(:ok)

    body = json
    expect(body).to include("world_id", "bundle", "messages")

    bundle = body["bundle"]
    expect(bundle).to include("room_id", "scene", "npcs", "items")

    scene = bundle["scene"]
    expect(scene).to be_a(Hash)
    # Optional keys — assert type only when present to avoid flakiness
    expect(scene["bg"]).to be_a(String) if scene.key?("bg")
    expect(scene["walkmesh"]).to be_a(Array) if scene.key?("walkmesh")
    expect(scene["hotspots"]).to be_a(Array) if scene.key?("hotspots")
    expect(scene["exits"]).to be_a(Array) if scene.key?("exits")

    # Full state still validates our existing schema
    get "/worlds/#{wid}/state"
    expect(response).to have_http_status(:ok)
    expect_json_schema!(json["state"], "game_state")
  end
end
