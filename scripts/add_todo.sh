#!/bin/bash

# Add a new todo via GraphQL
# Usage: ./scripts/add_todo.sh "Buy milk" "Need organic milk from the store"

TITLE="${1:-Untitled Todo}"
DESCRIPTION="${2:-}"

echo "Creating todo: '$TITLE'"
[ -n "$DESCRIPTION" ] && echo "Description: '$DESCRIPTION'"
echo ""

# Escape quotes for JSON
TITLE_ESCAPED=$(echo "$TITLE" | sed 's/"/\\"/g')
DESC_ESCAPED=$(echo "$DESCRIPTION" | sed 's/"/\\"/g')

QUERY="mutation {
  createTodo(title: \"$TITLE_ESCAPED\"$([ -n "$DESCRIPTION" ] && echo ", description: \"$DESC_ESCAPED\"" || echo "")) {
    id
    title
    description
    completed
  }
}"

curl -s -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d "{\"query\": $(echo "$QUERY" | jq -Rs .)}" | jq '.data.createTodo'
