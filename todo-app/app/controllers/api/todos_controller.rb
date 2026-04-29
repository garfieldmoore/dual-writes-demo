module Api
  class TodosController < ApplicationController
    def index
      search_ids = fetch_active_ids_from_search
      return render json: [], status: :ok if search_ids.empty?

      mode = Api::SettingsController.resolver_mode
      todos = if mode == 'where'
        Todo.with_discarded.where(id: search_ids)
      else
        Todo.with_discarded.find(search_ids)
      end

      todos_filtered = todos.map do |todo|
        todo.discarded? ? nil : todo
      end.compact

      render json: todos_filtered, status: :ok
    end

    def all
      todos = Todo.with_discarded.all
      render json: todos, status: :ok
    end

    def show
      todo = Todo.with_discarded.find_by(id: params[:id])

      if todo.nil?
        render json: { error: 'Todo not found' }, status: :not_found
      elsif todo.discarded?
        render json: todo.as_json.merge(discarded: true), status: :ok
      else
        render json: todo, status: :ok
      end
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
