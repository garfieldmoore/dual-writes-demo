class CreateTodos < ActiveRecord::Migration[7.0]
  def change
    create_table :todos do |t|
      t.string :title, null: false
      t.boolean :completed, default: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :todos, :discarded_at
  end
end
