class NarratorService
  def self.reply(world:, npc_id:, player_text:)
    # Default response if no external model configured
    {
      "npc_text" => "Arr, hello there.",
      "state_patch" => {
        "set" => {
          "npcs.pirate_jeff.mood" => "amused"
        }
      }
    }
  end
end
