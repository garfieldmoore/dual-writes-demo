#!/bin/bash

# View the current search app state
# Usage: ./scripts/view_search.sh

echo "=== Search App State ==="
echo ""

curl -s http://localhost:3001/todos/all | jq '.todos | sort_by(.id) | .[] | {id, is_deleted, created_at, deleted_at}'
