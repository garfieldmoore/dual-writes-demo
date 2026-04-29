#!/bin/bash

# Sync the search app with the current database state
# This reads all todos from the database and updates the search app
# Usage: ./scripts/sync_search_app.sh

echo "Syncing search app with database..."
echo ""

# Read from Rails database (using sqlite3 CLI)
cd todo-app

# Get all todos from the database (active and deleted)
TODOS=$(sqlite3 db/development.sqlite3 "SELECT id, discarded_at FROM todos;")

# For each todo, notify the search app
while IFS='|' read -r id discarded_at; do
  if [ -z "$discarded_at" ]; then
    ACTION="created"
  else
    ACTION="deleted"
  fi

  echo "  Syncing todo #$id ($ACTION)"

  curl -s -X POST http://localhost:3001/webhook/todos \
    -H "Content-Type: application/json" \
    -d "{\"id\": \"$id\", \"action\": \"$ACTION\"}" > /dev/null
done <<< "$TODOS"

cd ..

echo ""
echo "Sync complete!"
