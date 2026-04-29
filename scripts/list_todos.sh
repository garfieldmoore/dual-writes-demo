#!/bin/bash

# List all active todos (not soft-deleted)
# Usage: ./scripts/list_todos.sh

echo "Active todos:"
echo ""

curl -s -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ todos { id title description completed } }"}' | jq '.data.todos'
