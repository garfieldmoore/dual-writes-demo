Rails.application.routes.draw do
  root "home#index"

  get "/todos", to: "todos#index"  # View all todos in nice list

  post "/graphql", to: "graphql#execute"

  namespace :api do
    get "/todos", to: "todos#index"           # Active todos (filtered by search app)
    get "/todos/all", to: "todos#all"         # All todos including deleted
    get "/todos/:id", to: "todos#show"        # Single todo by ID
    get "/settings/mode", to: "settings#get_mode"
    post "/settings/mode", to: "settings#set_mode"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
