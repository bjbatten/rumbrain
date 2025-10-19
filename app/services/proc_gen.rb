# app/services/proc_gen.rb
class ProcGen
  VALID_DIFFICULTIES = %w[easy normal hard].freeze

  def self.build(seed:, difficulty: "normal")
    rng = Random.new(seed.hash)

    room_count = 7 # keep deterministic and within 6..9
    rooms = {}
    room_ids = (1..room_count).map { |i| "room_#{i}" }

    room_ids.each_with_index do |rid, i|
      next_id = room_ids[(i + 1) % room_count]
      # Deterministic scene metadata
      scene = {
        "bg" => "bg_room_#{i+1}.png",
        "walkmesh" => [ [ 0, 90, 320, 90 ] ],
        "hotspots" => {},
        "exits" => {
          "next" => { "rect" => [ 300, 80, 320, 100 ], "to" => next_id }
        }
      }
      # Add item hotspots
      scene["hotspots"] = {}
      # Add item hotspots for each item in this room
      # (items will be added after this loop, so add empty for now)
      rooms[rid] = {
        "desc"  => "A mysterious room #{i + 1} with faint smell of citrus.",
        "exits" => { "next" => next_id },
        "items" => [],
        "scene" => scene
      }
    end

    # Ensure at least 2 items are placed in distinct rooms
    item_ids = %w[item_1 item_2]
    selected_rooms = room_ids.sample(2, random: rng)
    item_ids.each_with_index do |iid, idx|
      target = selected_rooms[idx]
      rooms[target]["items"] << iid
      # Place a hotspot for the item
      rooms[target]["scene"]["hotspots"][iid] = { "rect" => [ 40 + idx*40, 80, 60 + idx*40, 100 ], "type" => "item" }
    end

    # NPCs live at top-level with required 'location'
    npcs = {
      "pirate_jeff" => {
        "location" => "room_3",
        "mood"     => "snarky",
        "flags"    => {},
        "pos"      => [ 160, 90 ],
        "sprite"   => "pirate_jeff.png"
      }
    }

    state = {
      "player" => {
        "room_id"  => "room_1",
        "inventory"=> [],
        "flags"    => {},
        "pos"      => [ 32, 90 ]
      },
      "rooms" => rooms,
      "npcs"  => npcs,
      "log"   => [ "World created." ]
    }
    state["flags"] ||= {}
    state
  end
end
