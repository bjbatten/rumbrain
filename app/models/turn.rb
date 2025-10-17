class Turn < ApplicationRecord
  belongs_to :world

  validates :action, presence: true
end
