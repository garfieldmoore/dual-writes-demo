#!/bin/bash

# Manually set or unset the deleted flag in the search app
# Usage: ./scripts/set_deleted.sh <id> [deleted|active]

TODO_ID="$1"
STATE="${2:-deleted}"

if [ -z "$TODO_ID" ]; then
  echo "Usage: ./scripts/set_deleted.sh <id> [deleted|active]"
  echo ""
  echo "Examples:"
  echo "  ./scripts/set_deleted.sh 1 deleted   # Mark todo #1 as deleted in search"
  echo "  ./scripts/set_deleted.sh 1 active    # Mark todo #1 as active in search"
  exit 1
fi

if [ "$STATE" == "deleted" ]; then
  ACTION="deleted"
  echo "Marking todo #$TODO_ID as DELETED in search app..."
elif [ "$STATE" == "active" ]; then
  ACTION="created"
  echo "Marking todo #$TODO_ID as ACTIVE in search app..."
else
  echo "Error: STATE must be 'deleted' or 'active'"
  exit 1
fi

curl -s -X POST http://localhost:3001/webhook/todos \
  -H "Content-Type: application/json" \
  -d "{\"id\": \"$TODO_ID\", \"action\": \"$ACTION\"}" | jq '.'

echo ""
echo "Search app updated!"
