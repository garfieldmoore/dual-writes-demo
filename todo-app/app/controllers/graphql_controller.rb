class GraphqlController < ApplicationController
  def execute
    variables = params[:variables] || {}
    query = params[:query]
    operation_name = params[:operationName]

    result = TodoSchema.execute(
      query,
      variables:,
      operation_name:,
      context: { current_user: nil }
    )

    render json: result
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
