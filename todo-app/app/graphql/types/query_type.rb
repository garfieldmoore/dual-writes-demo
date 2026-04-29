module Types
  class QueryType < Types::BaseObject
    field :todo, TodoType, null: true do
      argument :id, ID, required: true
    end

    field :todos, [TodoType], null: false

    def todo(id:)
      Todo.with_discarded.find_by(id: id)
    end

    def todos
      search_ids = fetch_active_ids_from_search
      return [] if search_ids.empty?

      mode = Api::SettingsController.resolver_mode
      todos = if mode == 'where'
        Todo.with_discarded.where(id: search_ids)
      else
        Todo.with_discarded.find(search_ids)
      end

      todos.map do |todo|
        if todo.discarded?
          nil
        else
          todo
        end
      end.compact
    end

    private

    def fetch_active_ids_from_search
      conn = Faraday.new(url: 'http://localhost:3001')
      response = conn.get('/todos')
      JSON.parse(response.body)['ids'] || []
    rescue StandardError => e
      Rails.logger.warn("Failed to fetch from search app: #{e.message}")
      []
    end
  end
end
