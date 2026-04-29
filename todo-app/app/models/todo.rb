class Todo < ApplicationRecord
  include Discard::Model

  validates :title, presence: true
end
