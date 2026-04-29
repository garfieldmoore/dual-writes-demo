# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Demonstrates how soft deletes (via the `discard` gem) handle sync lag gracefully when a search service returns IDs but hasn't synced deletions yet. The demo is interactive—you manually create, delete, sync, and observe behavior.

See README.md for the full problem and architecture. See DEMO.md for the interactive walkthrough.

## Quick Start

**Terminal 1 — Search App:**
```bash
cd search-app && npm install && npm start
```

**Terminal 2 — Rails App:**
```bash
cd todo-app && bundle install && rails db:create db:migrate && rails s
```

**Terminal 3 — Run scripts from repo root:**
```bash
./scripts/add_todo.sh "Title" "Description"
./scripts/view_db.sh
./scripts/sync_search_app.sh
./scripts/delete_todo.sh 1
./scripts/list_todos.sh
```

The demo shows how soft-deleted todos are filtered gracefully even when the search app hasn't synced yet.

## Architecture & Design

### Core Pattern: ID Resolution with Soft Deletes

1. **Search App** (Node) — returns active IDs only via `GET /todos`
2. **Todo App** (Rails) — calls search app for IDs, fetches from DB, filters discarded
3. **Manual Sync** — `./scripts/sync_search_app.sh` updates search app state

**Key:** `discard` gem marks records with `discarded_at` without removing rows. So:
- `Todo.all` excludes discarded (default scope)
- `Todo.with_discarded` includes both
- Resolver uses `with_discarded` to fetch potentially-deleted records, then filters

### Why No Webhooks?

Unlike real Debezium CDC, this demo doesn't auto-sync. You control sync manually via script. This makes the lag visible and testable—you can see the exact moment when search and DB are out of sync.

To add webhooks later, uncomment the `after_discard` callbacks in the Todo model and use Active Job for async posting.

## Key Files

- `todo-app/app/models/todo.rb` — includes `Discard::Model`, no auto-webhooks
- `todo-app/app/graphql/types/query_type.rb` — calls search app, fetches `with_discarded`, filters
- `todo-app/db/migrate/*_create_todos.rb` — schema with `discarded_at` column
- `search-app/src/index.js` — Express server for `/todos` (GET IDs) and `/webhook/todos` (POST sync)
- `search-app/src/store.js` — in-memory store of todo metadata
- `./scripts/*` — helper scripts for demo workflow

## Common Commands

**Rails:**
```bash
cd todo-app
rails db:create db:migrate              # Set up DB
rails s                                 # Start server
rails c                                 # Console
```

**Search App:**
```bash
cd search-app
npm install
npm start
```

**Demo Scripts (from repo root):**
```bash
./scripts/add_todo.sh "Title" "Description"
./scripts/list_todos.sh
./scripts/delete_todo.sh <id>
./scripts/view_db.sh
./scripts/view_search.sh
./scripts/sync_search_app.sh
./scripts/set_deleted.sh <id> [deleted|active]
```

## Testing & Debugging

**Manual curl queries:**
```bash
# Create
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createTodo(title: \"Test\", description: \"Desc\") { id title } }"}'

# List
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ todos { id title discarded } }"}'

# Delete
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { deleteTodo(id: \"1\") { id discarded } }"}'
```

**Rails console:**
```bash
rails c
todo = Todo.create!(title: "Test")
todo.discard
Todo.with_discarded.find(todo.id)  # Still exists
Todo.find(todo.id)                 # RecordNotFound (excluded by default scope)
```

**Database inspection:**
```bash
# SQLite CLI
cd todo-app
sqlite3 db/development.sqlite3
SELECT id, title, discarded_at FROM todos;

# Or use DBeaver GUI (download at dbeaver.io)
# File → New Connection → SQLite → /path/to/db/development.sqlite3
```

## Important Design Decisions

### Why `with_discarded` in the resolver
The GraphQL resolver needs to fetch potentially-deleted records (because search app might return the ID due to lag), check if they're discarded, and filter gracefully. Using the default scope would throw `RecordNotFound`.

### Why manual sync instead of webhooks
Keeps the demo simple and visible. You control when search and DB sync, making the lag behavior explicit and testable.

### In-memory store for search app
Simplicity. In production, this would be Elasticsearch or similar with real CDC. For this demo, restarting the search app clears state (which is fine—add SQLite backing if you need persistence).

### No federation gateway
The GraphQL schema uses federation patterns (`@key` directives) but there's no Apollo Gateway. This shows the pattern without complexity.

## Caveats

- **Search app is stateless:** restarting clears the in-memory store
- **Manual sync:** requires running `./scripts/sync_search_app.sh` explicitly
- **Default scope:** `discard` changes it, so `Todo.all` excludes deleted. Use `with_discarded` when needed.
- **No error handling:** sync failures are logged but not retried (add Active Job if needed)

## Extending the Demo

**Add persistence to search app:**
```bash
# Add SQLite to search-app/, persist store to DB
```

**Add automatic webhooks:**
```ruby
# In Todo model, uncomment/add:
after_discard { SearchSyncService.notify_deleted(id) }
after_create { SearchSyncService.notify_created(id) }

# Wrap calls in Active Job for async posting
```

**Add Apollo Gateway:**
```bash
# Install @apollo/gateway
# Expose /graphql with SDL (federation directives)
# Route queries through gateway
```

**Add database persistence to search app:**
```bash
# Add SQLite to search-app/
# Persist store in DB instead of memory
```

## Useful Resources

- Discard gem: https://github.com/jhawthorn/discard
- GraphQL Ruby: https://graphql-ruby.org
- DBeaver (DB GUI): https://dbeaver.io
