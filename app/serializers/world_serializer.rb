# app/serializers/world_serializer.rb
class WorldSerializer
  def self.render(world, messages: [])
    {
      world_id: world.id,
      state: world.game_state,   # must be a Hash
      messages: messages
    }
  end
end
