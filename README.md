# Rumbrain

Agent-flavored text adventure API.

## Apps
- **rumbrain/** – Rails 8 API (Postgres, UUID). Endpoints: see below.
- **docs/** – OpenAPI + `GameState` JSON Schema.

## Endpoints
- `POST /worlds` – create a new world
- `GET /worlds/:id/state` – get current world state
- `POST /worlds/:id/act` – perform an action (move, look, pickup, inventory, use)
- `POST /worlds/:id/npc/:npc_id/speak` – speak to an NPC
- `GET /resume/:code` – resume a saved game

## Quick cURL Examples
```bash
# Create a world
curl -X POST http://localhost:3000/worlds -d '{"seed":"banana"}' -H "Content-Type: application/json"

# Move to next room
curl -X POST http://localhost:3000/worlds/<id>/act -d '{"game_action":"move","payload":{"direction":"next"}}' -H "Content-Type: application/json"

# Speak to Pirate Jeff
curl -X POST http://localhost:3000/worlds/<id>/npc/pirate_jeff/speak -d '{"player_text":"hello"}' -H "Content-Type: application/json"
```

## Dev
```bash
cd rumbrain
bin/rails db:create db:migrate
bundle exec rspec
```