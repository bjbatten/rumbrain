class World < ApplicationRecord
  DIFFICULTIES = %w[easy normal hard].freeze
  has_many :turns, dependent: :destroy

  validates :difficulty, inclusion: { in: DIFFICULTIES }, allow_blank: true
  validates :seed, presence: true
  validates :game_state, presence: true
  validates :save_code, presence: true, uniqueness: true

  before_validation :set_default_difficulty
  before_validation :generate_save_code, on: :create

  def self.generate!(seed:, difficulty: "normal")
    world = new(
      seed: seed,
      difficulty: difficulty,
      game_state: ProcGen.build(seed: seed, difficulty: difficulty)
    )
    world.save!
    world
  end

  private

  def set_default_difficulty
    self.difficulty ||= "normal"
  end

  def generate_save_code
    self.save_code ||= SecureRandom.base36(6).downcase
  end
end
