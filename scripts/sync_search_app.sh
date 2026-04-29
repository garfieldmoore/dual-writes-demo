#!/bin/bash

# Sync the search app with the current database state
# This reads all todos from the database and updates the search app
# Usage: ./scripts/sync_search_app.sh

echo "Syncing search app with database..."
echo ""

cd todo-app

# Use Rails runner to read from database and post to search app
rails runner "
  Todo.with_discarded.all.each do |todo|
    action = todo.discarded? ? 'deleted' : 'created'
    payload = {id: todo.id.to_s, action: action, title: todo.title, description: todo.description}.to_json
    response = \`curl -s -X POST http://localhost:3001/webhook/todos \
      -H 'Content-Type: application/json' \
      -d '#{payload}'\`
    puts \"  Syncing todo ##{todo.id} (#{action})\"
  end
"

cd ..

echo ""
echo "Sync complete!"
