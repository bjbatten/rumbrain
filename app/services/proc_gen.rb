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
      rooms[rid] = {
        # SCHEMA KEYS:
        "desc"  => "A mysterious room #{i + 1} with faint smell of citrus.",
        "exits" => { "next" => next_id },
        # optional per schema:
        "items" => []
      }
    end

    # Ensure at least 2 items are placed in distinct rooms
    item_ids = %w[item_1 item_2]
    selected_rooms = room_ids.sample(2, random: rng)
    item_ids.each_with_index do |iid, idx|
      target = selected_rooms[idx]
      rooms[target]["items"] << iid
    end

    # NPCs live at top-level with required 'location'
    npcs = {
      "pirate_jeff" => {
        "location" => "room_3",
        "mood"     => "snarky",
        "flags"    => {}
      }
    }

    {
      "player" => {
        "room_id"  => "room_1",
        "inventory"=> [],
        "flags"    => {}
      },
      "rooms" => rooms,
      "npcs"  => npcs,
      "log"   => [ "World created." ]
    }
  end
end
