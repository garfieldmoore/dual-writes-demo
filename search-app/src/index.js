const express = require('express');
const bodyParser = require('body-parser');
const store = require('./store');

const app = express();
const PORT = 3001;

app.use(bodyParser.json());

app.get('/todos', (req, res) => {
  const ids = store.getTodos();
  res.json({ ids });
});

app.get('/todos/all', (req, res) => {
  const todos = store.getAllTodos();
  res.json({ todos });
});

app.post('/webhook/todos', (req, res) => {
  const { id, action } = req.body;

  if (!id || !action) {
    return res.status(400).json({ error: 'id and action are required' });
  }

  if (action === 'created' || action === 'updated') {
    store.addTodo(id);
    console.log(`[Search] Added/updated todo: ${id}`);
  } else if (action === 'deleted') {
    store.markDeleted(id);
    console.log(`[Search] Marked deleted: ${id}`);
  }

  res.json({ success: true });
});

app.listen(PORT, () => {
  console.log(`Search app listening on http://localhost:${PORT}`);
  console.log(`GET http://localhost:${PORT}/todos - returns active IDs`);
  console.log(`GET http://localhost:${PORT}/todos/all - returns all todos with is_deleted flag`);
  console.log(`POST http://localhost:${PORT}/webhook/todos - receive CDC updates`);
});
