# frozen_string_literal: true

require "rails_helper"
require "json_schemer"

RSpec.describe "Diagnostics smoke tests", type: :request do
  def json
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise "Response was not JSON (status #{response.status}):\n#{response.body}\n\n#{e.message}"
  end

  def pretty_fail!(msg)
    body = response.body
    raise "#{msg}\nSTATUS: #{response.status}\nBODY:\n#{body}"
  end



  def create_world(seed: "banana")
    post "/worlds", params: { seed: seed }
    pretty_fail!("POST /worlds failed") unless response.ok? || response.status == 201
    JSON.parse(response.body)["world_id"]
  end

  it "creates, moves, picks up, inventories, uses, speaks, and resumes via link", :aggregate_failures do
    wid = create_world

    # /state
    get "/worlds/#{wid}/state"
    pretty_fail!("GET /worlds/:id/state failed") unless response.ok?
    expect_json_schema!(json["state"], "game_state")

    # move
    get "/worlds/#{wid}/state"
    state = json["state"]
    start_room = state.dig("player", "room_id")
    next_dir   = state.dig("rooms", start_room, "exits")&.keys&.first
    if next_dir
      post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: next_dir } }
      pretty_fail!("POST /act move failed") unless response.ok?
    end

    # find a room with items and pick up one
    get "/worlds/#{wid}/state"
    state = json["state"]
    room_with_item, room_data = state["rooms"].find { |_, data| (data["items"] || []).any? } || []
    if room_with_item
      # walk along 'next' until we're in that room (bounded loop)
      10.times do
        break if state.dig("player", "room_id") == room_with_item
        post "/worlds/#{wid}/act", params: { game_action: "move", payload: { direction: "next" } }
        pretty_fail!("move toward item failed") unless response.ok?
        get "/worlds/#{wid}/state"
        state = json["state"]
      end
      item = (state.dig("rooms", room_with_item, "items") || []).first
      if item
        post "/worlds/#{wid}/act", params: { game_action: "pickup", payload: { item_id: item } }
        pretty_fail!("pickup failed") unless response.ok?
        expect(json["state"].dig("player", "inventory")).to include(item)
      end
    end

    # inventory (always allowed)
    post "/worlds/#{wid}/act", params: { game_action: "inventory" }
    pretty_fail!("inventory failed") unless response.ok?
    expect(json["messages"].join).to match(/inventory/i)

    # use (only if something in inventory)
    get "/worlds/#{wid}/state"
    inventory = json["state"].dig("player", "inventory") || []
    if inventory.any?
      item = inventory.first
      post "/worlds/#{wid}/act", params: { game_action: "use", payload: { item_id: item, target: "door" } }
      pretty_fail!("use failed") unless response.ok?
      expect(json["state"].dig("player", "inventory")).not_to include(item)
      expect(json["state"].dig("player", "flags", "used_items")).to include(item)
    end

    # speak
    post "/worlds/#{wid}/npc/pirate_jeff/speak", params: { player_text: "ahoy" }
    pretty_fail!("speak failed") unless response.ok?
    expect(json["npc_text"]).to be_a(String)
    expect_json_schema!(json["state"], "game_state")

    # resume via link
    code = World.find(wid).save_code
    get "/resume/#{code}"
    pretty_fail!("resume link failed") unless response.ok?
    expect_json_schema!(json["state"], "game_state")
  end
end
