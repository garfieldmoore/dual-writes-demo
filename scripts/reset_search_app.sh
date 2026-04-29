#!/bin/bash

# Reset the search app by clearing all todo data
# This removes all records from the search app's in-memory store
# Usage: ./scripts/reset_search_app.sh

echo "Resetting search app..."

response=$(curl -s -X POST http://localhost:3001/reset \
  -H 'Content-Type: application/json')

echo "Response: $response"
echo ""
echo "Search app reset complete!"
