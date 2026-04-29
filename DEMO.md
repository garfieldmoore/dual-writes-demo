# Interactive Demo: Soft Deletes vs Sync Lag

This guide walks you through the demo manually, so you can see the effects step-by-step.

## Quick Reference — URLs to View Data

Keep these URLs handy while running the demo:

| What | URL | Notes |
|------|-----|-------|
| **Todos List (HTML)** | http://localhost:3000/todos | Best view - shows active & deleted side-by-side, auto-refreshes |
| **Active Todos (JSON)** | http://localhost:3000/api/todos | What GraphQL returns (search app filtered) |
| **All Todos (JSON)** | http://localhost:3000/api/todos/all | All rows including soft-deleted ones |
| **Search App IDs** | http://localhost:3001/todos | What the search service knows about |

**CLI Commands:**
```bash
./scripts/view_db.sh      # Database state (see ACTIVE/DELETED status)
./scripts/view_search.sh  # Search app state
./scripts/list_todos.sh   # GraphQL response
```

---

## Setup

**Terminal 1 — Start the Search App (port 3001)**
```bash
cd search-app
npm install
npm start
```

**Terminal 2 — Start the Rails App (port 3000)**
```bash
cd todo-app
bundle install
rails db:create db:migrate  # or just rails db:migrate if DB exists
rails s
```

**Terminal 3 — Run the demo scripts**
```bash
cd /path/to/claude-demo  # Root of the repo
```

---

## The Scenario: Sync Lag

You have:
- **Rails app** (owns the data, has the database)
- **Search app** (returns only active todo IDs)
- **Sync lag** (search app hasn't been told about deletes yet)

The question: What happens when you soft-delete a todo before the search app knows about it?

---

## Demo Steps

### Step 1: Create some todos

```bash
./scripts/add_todo.sh "Buy milk" "Whole milk from the store"
./scripts/add_todo.sh "Walk the dog" "30 minute walk in the park"
./scripts/add_todo.sh "Write code" "Implement the feature"
```

Each returns the created todo with an ID (1, 2, 3, etc.).

### Step 2: Sync the search app

Tell the search app about all the todos in the database:

```bash
./scripts/sync_search_app.sh
```

This reads the database and notifies the search app of each todo.

### Step 3: View the current state

You can view the data in three ways:

**Browser — Nice HTML list (recommended):**
- **http://localhost:3000/todos** — All todos in a nice table (auto-refreshes every 2 seconds)
- Shows active and deleted todos side-by-side
- Best for seeing the full picture

**API — Raw JSON:**
- **http://localhost:3000/api/todos** — Active todos only (what search app returns)
- **http://localhost:3000/api/todos/all** — All todos including deleted
- **http://localhost:3001/todos** — Search app's active IDs (simple list)

**CLI — Command line:**
```bash
./scripts/view_db.sh      # See Rails database (all rows, marked ACTIVE/DELETED)
./scripts/view_search.sh  # See search app state (which IDs it knows about)
./scripts/list_todos.sh   # See GraphQL response (what client sees)
```

All three data sources should show the same 3 active todos:

### Step 4: Simulate sync lag — soft-delete a todo

Now, soft-delete todo #2 in the Rails app:

```bash
./scripts/delete_todo.sh 2
```

Notice in the response:
- `discarded: true`
- `discardedAt` is now set

**Check the database:**
```bash
./scripts/view_db.sh
```

Or visit **http://localhost:3000/todos** to see the HTML list. You'll see todo #2 is marked as DELETED, but the **row still exists** in the database.

### Step 5: The critical moment — don't sync yet!

This is where you see the sync lag. The search app hasn't been told about the deletion yet.

**Check what the search app knows:**
```bash
./scripts/view_search.sh
```

Or visit: **http://localhost:3001/todos** in browser (see the list of IDs)

The search app still thinks todo #2 is active! Now you have:
- **Database:** todo #2 is DELETED
- **Search app:** todo #2 is still ACTIVE
- **This is the sync lag**

### Step 6: Query the todos (the key insight)

```bash
./scripts/list_todos.sh
```

**What you'll see:** Only todos #1 and #3.

**Why it works:**
1. GraphQL asks search app for active IDs → gets [1, 2, 3]
2. Rails queries DB for todos with IDs [1, 2, 3]
3. Finds todo #2, but checks `discarded?` → true
4. Filters it out and returns [1, 3]
5. **No error thrown** ✓

This is the power of soft deletes. With a hard delete, todo #2 wouldn't exist in the DB, Rails would have no record, and GraphQL would error out.

### Step 7: Now sync the search app

```bash
./scripts/sync_search_app.sh
```

**Check the search app again:**
```bash
./scripts/view_search.sh
```

Or visit: **http://localhost:3001/todos** — now it only shows [1, 3]

The search app now knows todo #2 is deleted.

**View the todos list again:**
Visit **http://localhost:3000/todos** or:
```bash
./scripts/list_todos.sh
```

Still shows [1, 3], but now because the search app itself has filtered it out (not the resolver).

---

## Manual Testing with curl

**Create a todo:**
```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createTodo(title: \"Test\", description: \"Testing\") { id title } }"}'
```

**List todos:**
```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ todos { id title description discarded } }"}'
```

**Delete todo #1:**
```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { deleteTodo(id: \"1\") { id discarded } }"}'
```

**Manually set a todo as deleted in search app:**
```bash
curl -X POST http://localhost:3001/webhook/todos \
  -H "Content-Type: application/json" \
  -d '{"id": "1", "action": "deleted"}'
```

---

## Inspecting the Database

### Using SQLite CLI

```bash
cd todo-app
sqlite3 db/development.sqlite3

# View all todos
SELECT id, title, description, completed, discarded_at FROM todos;

# View only deleted todos
SELECT id, title FROM todos WHERE discarded_at IS NOT NULL;

# View only active todos
SELECT id, title FROM todos WHERE discarded_at IS NULL;

# Exit
.quit
```

### Using DBeaver (GUI)

1. **Download:** https://dbeaver.io
2. **Connect:**
   - File → New Database Connection → SQLite
   - Path: `/path/to/claude-demo/todo-app/db/development.sqlite3`
   - Test Connection → Finish
3. **Browse:** Left panel → sqlite → default → public → tables → todos
4. **Query:** Right-click todos → SQL Editor → New Script
5. **Write queries** and see results in real-time

---

## Key Files

- `./scripts/add_todo.sh` — Create a todo
- `./scripts/delete_todo.sh` — Soft-delete a todo from Rails
- `./scripts/list_todos.sh` — Query todos via GraphQL
- `./scripts/sync_search_app.sh` — Sync database state to search app
- `./scripts/set_deleted.sh` — Manually mark a todo as deleted/active in search
- `./scripts/view_db.sh` — View the Rails database
- `./scripts/view_search.sh` — View the search app state

---

## The Insight

**With soft deletes (discard):**
- Delete a todo → mark with `discarded_at` timestamp
- Row still exists in database
- GraphQL resolver can find it, check `discarded?`, and gracefully filter it out
- Even if search app hasn't synced yet, no error occurs

**Without soft deletes (hard delete):**
- Delete a todo → row is removed from database
- Search app still returns the ID (due to lag)
- GraphQL resolver tries to fetch, gets `ActiveRecord::RecordNotFound`
- Error propagates to client, query fails

**Why it matters:**
- Soft deletes are defensive against service sync lag
- No error handling needed in GraphQL layer for missing records
- Client always gets a clean, valid response
