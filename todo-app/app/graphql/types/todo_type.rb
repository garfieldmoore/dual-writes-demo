module Types
  class TodoType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false
    field :description, String, null: true
    field :completed, Boolean, null: false
    field :discarded_at, GraphQL::Types::ISO8601DateTime, null: true
    field :discarded, Boolean, null: false

    def discarded
      object.discarded?
    end
  end
end
