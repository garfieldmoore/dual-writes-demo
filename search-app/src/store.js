const store = new Map();

module.exports = {
  getTodos() {
    return Array.from(store.values())
      .filter(todo => !todo.is_deleted)
      .map(todo => todo.id);
  },

  getAllTodos() {
    return Array.from(store.values());
  },

  addTodo(id) {
    store.set(id, {
      id,
      is_deleted: false,
      created_at: new Date().toISOString(),
    });
  },

  markDeleted(id) {
    const todo = store.get(id);
    if (todo) {
      todo.is_deleted = true;
      todo.deleted_at = new Date().toISOString();
    }
  },

  markActive(id) {
    const todo = store.get(id);
    if (todo) {
      todo.is_deleted = false;
      todo.deleted_at = null;
    }
  },

  hasTodo(id) {
    return store.has(id);
  },
};
