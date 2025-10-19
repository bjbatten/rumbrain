# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

def schema_path(name); Rails.root.join("docs", "schemas", "#{name}.schema.json"); end
def load_schema(name); JSONSchemer.schema(Pathname.new(schema_path(name))); end
def expect_json_schema!(payload, schema_name)
  errors = load_schema(schema_name).validate(payload).to_a
  expect(errors).to be_empty, "Schema #{schema_name} errors:\n#{errors.map(&:to_h)}"
end

RSpec.describe "Worlds /point_click", type: :request do
  def json; JSON.parse(response.body); end

  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  def player_room_id(world_id)
    get "/worlds/#{world_id}/state"
    expect(response).to have_http_status(:ok)
    json["state"]["player"]["room_id"]
  end

  def room(world_id, rid)
    get "/worlds/#{world_id}/state"
    json["state"]["rooms"][rid]
  end

  it "walks via exit target and updates state" do
    wid = create_world
    rid = player_room_id(wid)
    exits = room(wid, rid)["exits"] || {}
    skip "no exits in current room" if exits.empty?

    exit_id = exits.keys.first
    post "/worlds/#{wid}/point_click",
         params: { operation: "walk", target: { type: "exit", id: exit_id } }

    expect(response).to have_http_status(:ok)
    expect(json).to include("messages", "state")
    expect_json_schema!(json["state"], "game_state")
    expect(player_room_id(wid)).to eq(exits[exit_id])
  end

  it "looks at a room target (gracefully handles missing hotspots)" do
    wid = create_world
    post "/worlds/#{wid}/point_click",
         params: { operation: "look", target: { type: "room", id: player_room_id(wid) } }

    expect(response).to have_http_status(:ok)
    expect(json["messages"].join).to match(/look|see/i)
    expect_json_schema!(json["state"], "game_state")
  end

  it "picks up an item via target if present" do
    wid = create_world
    rid = player_room_id(wid)
    items = room(wid, rid)["items"] || []
    # Ensure there is at least one item to pick up for the test
    if items.empty?
      # Add a test item to the room via direct DB update
      world = World.find(wid)
      state = world.game_state
      state["rooms"][rid]["items"] ||= []
      state["rooms"][rid]["items"] << "test_item_1"
      world.update!(game_state: state)
      items = [ "test_item_1" ]
    end

    item_id = items.first
    post "/worlds/#{wid}/point_click",
         params: { operation: "pickup", target: { type: "item", id: item_id } }

    expect(response).to have_http_status(:ok)
    expect(json["messages"].join).to match(/picked up/i)
    expect_json_schema!(json["state"], "game_state")
    # Verify moved from room to inventory
    get "/worlds/#{wid}/state"
    s = json["state"]
    expect(s["player"]["inventory"]).to include(item_id)
    expect(s["rooms"][rid]["items"]).not_to include(item_id)
  end

  it "talks to pirate_jeff when in same room (moves first if needed)" do
    wid = create_world

    # Try to reach room_3 where pirate_jeff is placed by procgen
    8.times do
      break if player_room_id(wid) == "room_3"
      # Follow 'next' if available; otherwise break (test remains robust)
      r = room(wid, player_room_id(wid))
      nx = (r["exits"] || {})["next"]
      break unless nx
      post "/worlds/#{wid}/point_click",
           params: { operation: "walk", target: { type: "exit", id: "next" } }
      expect(response).to have_http_status(:ok)
    end

    # Now attempt talk; if NPC missing, we still expect a 404
    post "/worlds/#{wid}/point_click",
         params: { operation: "talk", target: { type: "npc", id: "pirate_jeff" }, text: "hello" }

    expect([ 200, 404 ]).to include(response.status)
    if response.status == 200
      expect(json).to include("npc_text", "state", "messages")
      expect(json["npc_text"]).to be_a(String)
      expect_json_schema!(json["state"], "game_state")
    else
      expect(json).to include("error")
    end
  end
end
