module Types
  class MutationType < Types::BaseObject
    field :create_todo, Types::TodoType, null: true do
      argument :title, String, required: true
      argument :description, String, required: false
    end

    field :update_todo, Types::TodoType, null: true do
      argument :id, ID, required: true
      argument :title, String, required: false
      argument :completed, Boolean, required: false
    end

    field :delete_todo, Types::TodoType, null: true do
      argument :id, ID, required: true
    end

    field :hard_delete_todo, Types::TodoType, null: true do
      argument :id, ID, required: true
    end

    def create_todo(title:, description: nil)
      todo = Todo.create!(title:, description:, completed: false)
      todo
    rescue StandardError => e
      GraphQL::ExecutionError.new(e.message)
    end

    def update_todo(id:, title: nil, completed: nil)
      todo = Todo.find_by(id:)
      return GraphQL::ExecutionError.new("Todo not found") unless todo

      todo.update!(
        title: title || todo.title,
        completed: completed || todo.completed
      )
      todo
    rescue StandardError => e
      GraphQL::ExecutionError.new(e.message)
    end

    def delete_todo(id:)
      todo = Todo.find_by(id:)
      return GraphQL::ExecutionError.new("Todo not found") unless todo

      todo.discard
      todo
    rescue StandardError => e
      GraphQL::ExecutionError.new(e.message)
    end

    def hard_delete_todo(id:)
      todo = Todo.find_by(id:)
      return GraphQL::ExecutionError.new("Todo not found") unless todo

      todo.destroy
      todo
    rescue StandardError => e
      GraphQL::ExecutionError.new(e.message)
    end
  end
end
