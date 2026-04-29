#!/bin/bash

# View the current database state using Rails
# Usage: ./scripts/view_db.sh

echo "=== Todo Database State ==="
echo ""

cd todo-app
rails runner "
  puts '%-3s | %-20s | %-30s | %-9s | %-7s | %-19s' % ['ID', 'Title', 'Description', 'Completed', 'Status', 'Discarded At']
  puts '-' * 110

  Todo.with_discarded.all.each do |todo|
    status = todo.discarded? ? 'DELETED' : 'ACTIVE'
    discarded_at = todo.discarded_at ? todo.discarded_at.strftime('%Y-%m-%d %H:%M') : ''
    desc = (todo.description || '')
    desc = desc.length > 28 ? desc[0..27] + '..' : desc
    puts '%-3s | %-20s | %-30s | %-9s | %-7s | %-19s' % [
      todo.id,
      todo.title[0..18],
      desc,
      todo.completed ? 'true' : 'false',
      status,
      discarded_at
    ]
  end
"
cd ..
