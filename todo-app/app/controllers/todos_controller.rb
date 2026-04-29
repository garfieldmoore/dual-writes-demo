class TodosController < ActionController::Base
  def index
    render :index, layout: false
  end
end
