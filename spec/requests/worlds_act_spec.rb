# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

RSpec.describe "Worlds /act", type: :request do
  def json; JSON.parse(response.body); end
  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)["world_id"]
  end

  it "moves the player along a valid exit (POST /act move)" do
    wid = create_world
    # initial state
    get "/worlds/#{wid}/state"
    start_room = json["state"]["player"]["room_id"]
    next_room = json["state"]["rooms"][start_room]["exits"]["next"]

    post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
    expect(response).to have_http_status(:ok)
    expect(json).to include("world_id", "state", "messages")
    expect(json["state"]["player"]["room_id"]).to eq(next_room)
  expect_json_schema!(json["state"], "game_state")
  end

  it "returns info about the current room (POST /act look)" do
    wid = create_world
    get "/worlds/#{wid}/state"
    room_id = json["state"]["player"]["room_id"]
    desc = json["state"]["rooms"][room_id]["desc"]

    post "/worlds/#{wid}/act", params: { game_action: "look", payload: {} }
    expect(response).to have_http_status(:ok)
    expect(json["messages"].join(" ")).to include(desc)
  expect_json_schema!(json["state"], "game_state")
  end

  it "picks up an item present in the room (POST /act pickup)" do
    wid = create_world
    # Find a room with at least one item:
    get "/worlds/#{wid}/state"
    state = json["state"]
    room_with_item = state["rooms"].detect { |_, data| (data["items"] || []).any? }&.first
    pending "procgen seeded no items; adjust seed or procgen to always place items" unless room_with_item

    # Move player to that room if needed
    current = state["player"]["room_id"]
    if current != room_with_item
      # brute-follow 'next' until we're there (loop is small)
      10.times do
        break if current == room_with_item
        next_id = state["rooms"][current]["exits"]["next"]
        post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
        expect(response).to have_http_status(:ok)
        get "/worlds/#{wid}/state"
        state = json["state"]
        current = state["player"]["room_id"]
      end
    end

    item = state["rooms"][room_with_item]["items"].first
    post "/worlds/#{wid}/act", params: { game_action: "pickup", payload: { item: item } }
    expect(response).to have_http_status(:ok)

    get "/worlds/#{wid}/state"
    new_state = json["state"]
    expect(new_state["player"]["inventory"]).to include(item)
    expect(new_state["rooms"][room_with_item]["items"]).not_to include(item)
  expect_json_schema!(new_state, "game_state")
  end

  it "rejects invalid move direction" do
    wid = create_world
    post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "north" } }
    expect(response).to have_http_status(:bad_request)
    expect(json).to include("error")
  end

  it "rejects pickup of missing item" do
    wid = create_world
    post "/worlds/#{wid}/act", params: { game_action: "pickup", payload: { item: "ghost_coin" } }
    expect(response).to have_http_status(:bad_request)
    expect(json).to include("error")
  end
end
