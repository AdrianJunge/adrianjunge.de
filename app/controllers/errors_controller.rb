class ErrorsController < ApplicationController
  def bad_request
    render_error_page(:bad_request)
  end

  def not_found
    render_error_page(:not_found)
  end

  def unprocessable_entity
    render_error_page(:unprocessable_entity)
  end

  def internal_server_error
    render_error_page(:internal_server_error)
  end
end
