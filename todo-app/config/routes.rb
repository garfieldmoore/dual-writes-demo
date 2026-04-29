Rails.application.routes.draw do
  root "home#index"

  post "/graphql", to: "graphql#execute"

  namespace :api do
    get "/todos", to: "todos#index"           # Active todos (filtered by search app)
    get "/todos/all", to: "todos#all"         # All todos including deleted
    get "/todos/:id", to: "todos#show"        # Single todo by ID
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
