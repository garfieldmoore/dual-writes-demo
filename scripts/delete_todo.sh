#!/bin/bash

# Soft-delete a todo (mark as discarded)
# Usage: ./scripts/delete_todo.sh 1

TODO_ID="$1"

if [ -z "$TODO_ID" ]; then
  echo "Usage: ./scripts/delete_todo.sh <id>"
  echo "Example: ./scripts/delete_todo.sh 1"
  exit 1
fi

echo "Soft-deleting todo #$TODO_ID..."
echo ""

curl -s -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"mutation { deleteTodo(id: \\\"$TODO_ID\\\") { id title discarded discardedAt } }\"}" | jq '.data.deleteTodo'
