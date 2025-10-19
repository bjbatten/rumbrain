# app/serializers/world_serializer.rb
class WorldSerializer
  def self.render(world, messages: [])
    state = world.game_state.is_a?(Hash) ? world.game_state : JSON.parse(world.game_state.to_json)
    {
      world_id: world.id,
      state: state,
      messages: messages
    }
  end
end
