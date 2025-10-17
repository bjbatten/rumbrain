class World < ApplicationRecord
  has_many :turns, dependent: :destroy

  validates :seed, presence: true
  validates :game_state, presence: true
  validates :difficulty, inclusion: { in: [ "easy", "normal", "hard" ] }, allow_blank: true

  before_validation :set_default_difficulty

  def self.generate!(seed:, difficulty: "normal")
    world = new(
      seed: seed,
      difficulty: difficulty,
      game_state: {
        "player" => {
          "room_id" => "room_1",
          "inventory" => [],
          "flags" => {}
        },
        "rooms" => {},
        "npcs" => {},
        "log" => [ "World created." ]
      }
    )
    world.save!
    world
  end

  private

  def set_default_difficulty
    self.difficulty = "normal" if difficulty.nil?
  end
end
