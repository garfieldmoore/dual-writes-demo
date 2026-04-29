# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This is a demo showing how soft deletes (via the `discard` gem) handle sync lag gracefully in a microservices architecture where a search service returns IDs and a data service resolves them. The problem it solves: hard deletes cause "not found" errors when the search service hasn't synced yet, but soft deletes let the resolver handle it gracefully.

See README.md for the full problem description and architecture.

## Quick Start

**Terminal 1 — Search App (Node.js, port 3001):**
```bash
cd search-app
npm install
npm start
```

**Terminal 2 — Rails App (port 3000):**
```bash
cd todo-app
bundle install
rails db:create db:migrate
rails s
```

**Terminal 3 — Run the test scenario:**
```bash
bash /tmp/test_demo.sh
```

The test creates 3 todos, soft-deletes one, and verifies the GraphQL query filters it out gracefully (no error).

## Architecture & Design

### The Core Pattern: ID Resolution with Soft Deletes

1. **Search App** (Node) — stores todo metadata + `is_deleted` flag, returns only active IDs via `GET /todos`
2. **Todo App** (Rails) — owns full records, calls search app to get IDs, resolves them from local DB
3. **Webhook Sync** — when a todo is soft-deleted, Rails notifies search app via `POST /webhook/todos`

**Key insight:** `discard` gem marks records with `discarded_at` without removing rows. This means:
- `Todo.all` excludes discarded (default scope)
- `Todo.with_discarded` includes them
- Resolver can check `discarded?` and filter gracefully

### Why This Matters

**Hard delete scenario (breaks):**
- Search still returns ID → Rails tries to fetch → `ActiveRecord::RecordNotFound` → GraphQL error propagates to client

**Soft delete scenario (works):**
- Search still returns ID → Rails fetches (record exists, just marked discarded) → resolver returns `null` → client gets clean list

## Key Files

- `todo-app/app/models/todo.rb` — model with `include Discard::Model`; has after-hooks to notify search app
- `todo-app/app/services/search_sync_service.rb` — makes webhook calls to search-app (simulates Debezium CDC)
- `todo-app/app/graphql/types/query_type.rb` — main resolver; calls search app, fetches with `with_discarded`, filters discarded
- `todo-app/db/migrate/20240429000001_create_todos.rb` — schema includes `discarded_at` column (required by discard gem)
- `search-app/src/store.js` — in-memory store for todo metadata (id, is_deleted, timestamps)
- `search-app/src/index.js` — Express server; routes for `/todos` (GET active IDs) and `/webhook/todos` (POST to mark deleted)

## Common Commands

**Rails:**
```bash
cd todo-app
bundle install                    # Install gems
rails db:create db:migrate        # Set up database
rails s                           # Start server (port 3000)
rails c                           # Console (test queries)
```

**Search App:**
```bash
cd search-app
npm install                       # Install dependencies
npm start                         # Start (port 3001)
```

**Queries:**
```bash
# Create a todo
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createTodo(title: \"Test\") { id title } }"}'

# List todos
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ todos { id title completed discarded } }"}'

# Soft-delete a todo (replace ID with real ID)
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { deleteTodo(id: \"1\") { id discarded } }"}'

# Check search app state
curl http://localhost:3001/todos              # Active IDs only
curl http://localhost:3001/todos/all          # All with is_deleted flag
```

## Important Design Decisions

### Why search app returns only IDs
This mirrors real search services (Elasticsearch, etc.) that are designed to be lightweight. The data app owns full records and resolves by ID.

### Why `Todo.with_discarded` in the resolver
We need to fetch potentially-deleted records (due to sync lag), check if they're discarded, and filter gracefully. If we used the default scope, we'd get an error when the ID exists in search but is discarded locally.

### Why webhooks instead of polling
Simulates Debezium CDC, which is event-driven. Faster and more realistic than polling the search app.

### In-memory store for search app
Keeps the demo simple; in production this would be a real search index (Elasticsearch, etc.) with actual CDC from the data source.

## Testing & Debugging

**See the sync lag in action:**
1. Create a todo: search app receives webhook and stores it
2. Soft-delete the todo: Rails calls `todo.discard`, search app is notified
3. Immediately query todos: search still has the ID, but resolver filters it out gracefully
4. Wait a moment, query again: after search syncs, ID no longer appears at all

**Check search app state:**
```bash
curl http://localhost:3001/todos/all | jq '.todos[] | select(.is_deleted == true)'
```

**Manual resolver test (in Rails console):**
```ruby
cd todo-app
rails c

# Create a todo
todo = Todo.create!(title: "Test")

# Soft-delete it
todo.discard

# Try to fetch (still exists)
Todo.with_discarded.find(todo.id)  # Works, record exists
Todo.find(todo.id)                 # RecordNotFound (excluded by default scope)

# Check discarded status
todo.reload.discarded?             # true
```

## Caveats

- **Search app is stateless:** restarting it clears the in-memory store. For a real demo, add SQLite backing.
- **Webhook calls are fire-and-forget:** Rails logs failures but doesn't retry. In production, use a job queue.
- **No federation gateway:** the GraphQL schema uses federation patterns (@key directives) but there's no Apollo Gateway. This shows the pattern without the complexity.
- **Default scope includes soft-deleted:** When querying from Rails console or creating associations, remember `discard` changes the default scope. Use `with_discarded` when you need deleted records.

## Extending the Demo

**To add persistence to search app:**
- Add SQLite or PostgreSQL to `search-app/`
- Persist the store to DB in `store.js`

**To add retry logic for webhooks:**
- Use Active Job in Rails instead of direct HTTP calls
- Wrap `SearchSyncService.notify_*` in a background job

**To add a real federation gateway:**
- Install `@apollo/gateway`
- Expose subgraph at `/graphql` with SDL
- Route federated queries through the gateway instead of directly to Rails

**To simulate longer sync lag:**
- Add a delay parameter to the search app webhook: `POST /webhook/todos?delay=true` doesn't update immediately
- Or add a middleware to search app that queues updates asynchronously
