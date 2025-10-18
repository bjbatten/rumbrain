# Monkeymind

Funny, agent-flavored text adventure.

## Apps
- **rumbrain/** – Rails 8 API (Postgres, UUID). Endpoints: `/worlds`, `/worlds/:id/state`, `/worlds/:id/act`, (soon) `/worlds/:id/npc/:npc_id/speak`.
- **docs/** – OpenAPI + `GameState` JSON Schema.

## Dev
```bash
cd rumbrain
bin/rails db:create db:migrate
bundle exec rspec