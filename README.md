# Dual Writes Demo: Soft Deletes with Sync Lag

This demo shows how soft deletes (via the `discard` gem) handle sync lag gracefully when using a search/index service that returns IDs.

## The Problem

In a microservices architecture:
- **Search service** stores metadata and returns only active IDs: `[1, 2, 3]`
- **Data service** owns full records, fetches by ID, resolves them in GraphQL
- **Sync lag** occurs when data service deletes before search service syncs

**Hard Delete Scenario:**
```
1. Delete todo #2 from DB (hard delete)
2. Search app still returns [1, 2, 3] (hasn't synced yet)
3. GraphQL resolver tries to fetch todo #2
4. Result: ActiveRecord::RecordNotFound error
5. Query fails, client sees error ❌
```

**Soft Delete Scenario:**
```
1. Soft-delete todo #2 (mark as discarded_at, row still exists)
2. Search app still returns [1, 2, 3] (hasn't synced yet)
3. GraphQL resolver fetches todo #2 (it exists), checks discarded?
4. Resolver filters it out gracefully, returns [1, 3]
5. Query succeeds, client sees clean list ✓
```

## Quick Start

### 1. Start the apps
**Terminal 1:**
```bash
cd search-app && npm install && npm start
```

**Terminal 2:**
```bash
cd todo-app && bundle install && rails db:create db:migrate && rails s
```

### 2. Open the web UI
Open **http://localhost:3000/todos** in your browser. You'll see:
- A form to add new todos (title + description)
- Two sections: "Active Todos" and "Soft-Deleted Todos"
- **Soft Delete** button (yellow) — keeps record in database
- **Hard Delete** button (red) — removes record from database
- **Resolver** toggle (find/where) — switch between resolution strategies

### 3. See the difference between hard and soft deletes

**Step 1: Add todos and sync**
```bash
# In browser, add 3 todos via the form
# Then sync the search app to know about them
./scripts/sync_search_app.sh
```

**Step 2: Hard delete and observe the behavior**
- Hard delete todo #2 in the browser (don't sync the search app yet)
- Notice: The row moves to "Soft-Deleted" section and is **gone from the database**
- But the search app still thinks #2 is active!

**Step 3: Try querying with `find` resolver**
- Make sure you're on **find** (toggle shows "find")
- The query breaks! You see: `⚠️ Query failed`
- Search app returned an ID that no longer exists in the database

**Step 4: Switch to `where` resolver**
- Click **Toggle** to switch to **where**
- The query works now! But todo #2 is missing from the results
- Different behavior than find

**Step 5: Now try soft delete instead**
- Add new todos and sync
- **Soft Delete** one (yellow button instead of red)
- The query works in both `find` and `where`!
- The record is still in the database, just marked as deleted

### Typical Workflow

To start fresh and demonstrate the behavior cleanly:

```bash
# 1. Reset the search app
./scripts/reset_search_app.sh

# 2. Add todos in the browser
# (or via ./scripts/add_todo.sh)

# 3. Sync the search app to know about them
./scripts/sync_search_app.sh

# 4. Hard delete a todo in the browser (or via ./scripts/delete_todo.sh)
# (Don't sync yet - this creates the lag)

# 5. See what happens:
# - In `find` resolver: query breaks
# - In `where` resolver: todo is missing

# 6. Then try soft delete to see it work in both modes
```

**For more detailed step-by-step instructions, see [DEMO.md](DEMO.md)**

---

## How It Works

### The Flow

```
Client
  ↓ GraphQL query: { todos { id title } }
Rails App (port 3000)
  ↓ "Get active todo IDs from search app"
Search App (port 3001)
  ↓ returns: [1, 2, 3]
Rails App
  ↓ "Fetch todos with IDs [1, 2, 3] from DB"
  ↓ Todo.with_discarded.where(id: ids)
  ↓ Found: 1 (active), 2 (DISCARDED), 3 (active)
  ↓ "Filter out discarded? -> true"
  ↓ returns: [1, 3]
Client
  ← receives: [{ id: 1, title: "..." }, { id: 3, title: "..." }]
```

### Key Code

**Model — includes soft delete support:**
```ruby
class Todo < ApplicationRecord
  include Discard::Model  # Adds discard, undiscard, discarded? methods
  validates :title, presence: true
end
```

**Migration — includes discarded_at column:**
```ruby
create_table :todos do |t|
  t.string :title, null: false
  t.text :description
  t.boolean :completed, default: false
  t.datetime :discarded_at  # Discard gem uses this
  t.timestamps
end
```

**GraphQL Resolver — the critical part (with mode toggle):**
```ruby
def todos
  search_ids = fetch_active_ids_from_search  # [1, 2, 3]
  mode = Api::SettingsController.resolver_mode  # 'find' or 'where'
  
  todos = if mode == 'where'
    Todo.with_discarded.where(id: search_ids)
  else
    Todo.with_discarded.find(search_ids)
  end
  
  todos.map do |todo|
    todo.discarded? ? nil : todo  # Filter out discarded
  end.compact
end
```

**What you observe:**
- **Mode A** — fails when search app returns ID of hard-deleted todo → exposes the sync lag problem
- **Mode B** — works but skips the hard-deleted record → hides the problem
- **With soft deletes** — both modes work because deleted rows still exist → no problem either way ✓

### Why `with_discarded`?

The `discard` gem changes the default scope:
- `Todo.all` — excludes discarded records (default)
- `Todo.with_discarded` — includes both active and discarded

We need `with_discarded` because:
1. Search app returns IDs (including potentially-deleted ones due to lag)
2. We fetch all those IDs from the database
3. We check which are discarded
4. We filter gracefully

If we used the default scope, we'd get `RecordNotFound` when the search app returns a discarded ID.

---

## Scripts

All scripts in `./scripts/` directory:

| Script | Purpose |
|--------|---------|
| `add_todo.sh` | Create a new todo |
| `list_todos.sh` | Query todos via GraphQL |
| `delete_todo.sh` | Soft-delete a todo |
| `sync_search_app.sh` | Sync DB state to search app |
| `set_deleted.sh` | Manually mark as deleted/active in search |
| `view_db.sh` | View Rails database |
| `view_search.sh` | View search app state |

---

## Architecture

### Search App (Node.js, port 3001)
- Stores todo metadata: `{ id, is_deleted, created_at, deleted_at }`
- `GET /todos` — returns active IDs only
- `GET /todos/all` — returns all with is_deleted flag
- `POST /webhook/todos` — receives sync updates

### Todo App (Rails, port 3000)
- GraphQL API at `POST /graphql`
- Database: SQLite (`db/development.sqlite3`)
- Models use `discard` gem for soft deletes
- Resolvers call search app to get IDs, then fetch from DB

### No Webhooks
Unlike real Debezium, this demo doesn't auto-sync. You control sync with `./scripts/sync_search_app.sh`. This makes the lag visible and testable.

---

## Inspecting the Database

### SQLite CLI
```bash
cd todo-app
sqlite3 db/development.sqlite3
SELECT id, title, discarded_at FROM todos;
```

### DBeaver (GUI)
1. Download: https://dbeaver.io
2. New SQLite connection → `/path/to/claude-demo/todo-app/db/development.sqlite3`
3. Browse tables, query, edit live

---

## Gems & Dependencies

**Rails:**
- `discard` — soft deletes (marks with `discarded_at` instead of deleting)
- `graphql` — GraphQL schema and resolvers
- `faraday` — HTTP client for calling search app

**Node:**
- `express` — web server
- `body-parser` — JSON parsing

---

## Key Insight

When a search service returns IDs with sync lag, hard deletes create a dilemma:
- **`find` resolver** — query breaks when record doesn't exist
- **`where` resolver** — data goes missing silently

**Soft deletes solve this:**
- Records are marked as deleted but remain in the database
- Both resolvers work because the record still exists
- The system gracefully filters out deleted records without breaking

> Soft deletes are defensive against sync lag. The entire distributed system remains consistent even when different services are temporarily out of sync.

---

## Extending

**Add real persistence to search app:**
- Add SQLite to `search-app/`
- Save/load state from DB

**Add retry logic to sync:**
- Wrap sync in Rails job queue
- Implement exponential backoff

**Add webhooks back in:**
- Uncomment `after_discard` hooks in Todo model
- Use Active Job to post webhooks asynchronously

**Add federation gateway:**
- Setup Apollo Gateway
- Expose search app as a subgraph with `@key` directives

---

## See Also

- [DEMO.md](DEMO.md) — Step-by-step interactive walkthrough
- [CLAUDE.md](CLAUDE.md) — Development guidance
