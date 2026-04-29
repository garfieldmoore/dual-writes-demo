# Soft Deletes Demo: Handling Sync Lag

This demo shows how soft deletes (via the `discard` gem) handle sync lag gracefully when a search service returns IDs but hasn't synced deletions yet.

## The Problem

When using a search service for ID lookups:
- Search service returns `[1, 2, 3]` (only active IDs)
- Data service owns full records and syncs with search service
- **Sync lag** occurs when data service deletes before search service syncs

**Hard Delete:** Row removed immediately
```
1. Delete todo #2 from DB (hard delete)
2. Search app still returns [1, 2, 3] (hasn't synced yet)
3. GraphQL resolver tries to fetch #2
4. Error: RecordNotFound ❌
```

**Soft Delete:** Row marked as deleted, still exists
```
1. Mark todo #2 as deleted (discarded_at timestamp)
2. Search app still returns [1, 2, 3] (hasn't synced yet)
3. GraphQL resolver finds #2 (row exists), checks if discarded
4. Filters it out gracefully, returns [1, 3] ✓
```

## Quick Start

**Terminal 1 — Search App:**
```bash
cd search-app && npm install && npm start
```

**Terminal 2 — Rails App:**
```bash
cd todo-app && bundle install && rails db:create db:migrate && rails s
```

**Terminal 3 — Open the web UI:**
```
http://localhost:3000/todos
```

## Demo Steps

1. **Add todos and sync:**
   ```bash
   ./scripts/reset_search_app.sh
   ./scripts/sync_search_app.sh
   ```

2. **Hard delete a todo** in the browser (red button) — don't sync the search app yet

3. **Try the `find` resolver:**
   - Toggle shows "find"
   - Query breaks: `⚠️ Query failed`
   - This is the problem: search app returned an ID that no longer exists

4. **Switch to `where` resolver:**
   - Click Toggle to switch
   - Query works, but the deleted todo is missing

5. **Now try soft delete instead:**
   - Add new todos and sync
   - Soft delete (yellow button)
   - Query works in both resolvers!
   - Record still in database, just marked deleted

## Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/reset_search_app.sh` | Clear search app state |
| `./scripts/sync_search_app.sh` | Sync database to search app |
| `./scripts/add_todo.sh` | Create a todo via GraphQL |
| `./scripts/delete_todo.sh` | Soft-delete a todo |
| `./scripts/view_db.sh` | View database contents |
| `./scripts/view_search.sh` | View search app contents |

## Key Insight

Soft deletes are defensive against sync lag. Rows stay in the database (marked as deleted), so resolvers can handle stale search results gracefully without breaking the query or losing data.

---

## Technical Note: `find` vs `where` Resolvers

The demo includes a resolver toggle to show different query strategies:
- **`find` mode** — throws error if any ID is missing from database
- **`where` mode** — silently skips missing IDs

With **hard deletes**, each mode has a problem. With **soft deletes**, both work because deleted rows still exist in the database.
