#!/bin/bash

# View the current database state
# Usage: ./scripts/view_db.sh

echo "=== Todo Database State ==="
echo ""

cd todo-app
sqlite3 db/development.sqlite3 << 'EOF'
.headers on
.mode column
SELECT id, title, description, completed,
       CASE WHEN discarded_at IS NULL THEN 'ACTIVE' ELSE 'DELETED' END as status,
       discarded_at
FROM todos
ORDER BY id;
EOF

cd ..
