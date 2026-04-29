module Api
  class SettingsController < ApplicationController
    @@resolver_mode = 'find'

    def get_mode
      render json: { mode: @@resolver_mode }
    end

    def set_mode
      mode = params[:mode]
      if ['find', 'where'].include?(mode)
        @@resolver_mode = mode
        render json: { mode: @@resolver_mode, message: "Switched to #{mode}" }
      else
        render json: { error: 'Invalid mode. Use find or where' }, status: :bad_request
      end
    end

    def self.resolver_mode
      @@resolver_mode
    end
  end
end
