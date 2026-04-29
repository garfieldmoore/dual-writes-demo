# Todo List Demo: Soft Deletes with Sync Lag

This demo shows how soft deletes (via the `discard` gem) are defensive against service sync lag when using a search/index service with CDC (Change Data Capture) events.

## The Problem

In a microservices architecture with a search service that returns IDs:

1. **Search service** stores a record and returns only its ID (e.g., `[1, 2, 3]`)
2. **Data service** fetches full records by ID and resolves them in GraphQL
3. **Sync lag** occurs when the data service deletes a record before the search service syncs (via Debezium or similar CDC events)

**Without soft deletes (hard delete):**
- Record is removed from DB
- Search service still returns the ID
- GraphQL resolver throws "not found" error
- **Result:** Error propagates to the client, breaking the query

**With soft deletes (discard):**
- Record is marked as deleted but still exists in the DB
- Search service still returns the ID (temporarily, due to lag)
- GraphQL resolver can fetch the record, see it's discarded, and return `null`
- **Result:** No error, the query succeeds with a filtered list

## Architecture

```
┌─────────────┐
│  Client     │
└──────┬──────┘
       │ GraphQL query
       ↓
┌─────────────────────────────┐
│  Todo App (Rails)           │
│  - GraphQL resolvers        │
│  - Discard gem (soft delete)│
└──────────────┬──────────────┘
       │ 1. fetch active IDs
       ↓
┌──────────────────────────────┐
│  Search App (Node.js)        │
│  - Returns [id1, id2, id3]   │
│  - Stores is_deleted flag    │
└──────────────┬───────────────┘
       │ 2. webhook (Debezium simulation)
       ↓
    (Update deleted status with lag)
```

## Running the Demo

### 1. Start the Search App

```bash
cd search-app
npm install
npm start
# Listening on http://localhost:3001
```

### 2. Start the Rails App

```bash
cd todo-app
bundle install
rails db:create db:migrate
rails s
# Listening on http://localhost:3000
```

### 3. Test the Scenario

```bash
bash /tmp/test_demo.sh
```

This script:
1. Creates 3 todos via GraphQL mutation
2. Verifies they appear in the search app
3. Queries todos and shows all 3 appear
4. Soft-deletes one todo (via `discard`)
5. Verifies the search app is notified (webhook)
6. Queries todos again → deleted one is filtered out, no error

## Key Code

### Soft Delete Model (Rails)

```ruby
class Todo < ApplicationRecord
  include Discard::Model  # Adds soft delete support

  after_discard :notify_search_app_deleted
end
```

### GraphQL Resolver

```ruby
def todos
  search_ids = fetch_active_ids_from_search  # Get IDs from search service
  todos = Todo.with_discarded.where(id: search_ids)

  todos.map do |todo|
    todo.discarded? ? nil : todo  # Filter out discarded, no error
  end.compact
end
```

### Webhook Sync (Simulates Debezium)

```ruby
class SearchSyncService
  def self.notify_deleted(id)
    post_to_search_app(id, 'deleted')  # Update search service
  end
end
```

## The Insight

**Soft deletes are defensive.** Even if sync lag causes the search service to return a deleted ID, the data service can gracefully handle it:
- No database errors (record exists)
- No GraphQL errors (resolver handles `nil` values)
- Client gets a clean result set

This is much more elegant than hard deletes, which require error handling at the GraphQL layer to catch "not found" scenarios.

## Files

- `search-app/` — Node.js/Express service (simulates search/index domain)
- `todo-app/` — Rails API with GraphQL (owns the data)

## Gems Used

- **discard** — Soft delete implementation (marks as discarded_at instead of removing rows)
- **graphql** — GraphQL schema and resolvers
- **faraday** — HTTP client for webhook calls

## Testing Variations

To simulate different sync lag scenarios:

**No lag (search syncs immediately):**
```bash
# Just run the normal test
```

**Simulate lag (search hasn't synced yet):**
```bash
# Manually query after deletion, before search app updates
curl http://localhost:3001/todos  # Still returns deleted ID
curl http://localhost:3000/graphql -d '{ todos { id title } }'
# Still gracefully filters deleted, no error
```
