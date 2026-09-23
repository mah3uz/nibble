module Admin
  class PreferencesController < BaseController
    def update
      UserPreferences.set!(Current.user, params.require(:key), params[:value])
      head :no_content
    rescue ArgumentError, UserPreferences::InvalidValue => error
      render json: { error: error.message }, status: :unprocessable_entity
    end
  end
end
