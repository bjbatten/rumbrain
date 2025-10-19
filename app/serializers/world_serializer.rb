# app/serializers/world_serializer.rb
class WorldSerializer
  def self.render(world, messages: [], effects: nil)
    state = world.game_state.is_a?(Hash) ? world.game_state : JSON.parse(world.game_state.to_json)
    result = {
      world_id: world.id,
      state: state,
      messages: messages
    }
    result[:effects] = effects if effects && !effects.empty?
    result
  end
end
