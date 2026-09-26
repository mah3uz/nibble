# CMS password reset (Rails 8 authentication), rendered in the Control Plane.
module Nibble
  module Cp
    class PasswordsController < ApplicationController
      layout "nibble/cp"
      allow_unauthenticated_access
      before_action :set_user_by_token, only: %i[ edit update ]
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_cp_password_path, alert: "Try again later." }

      def new
        render inertia: "cp/auth/ForgotPassword", props: { flash: flash.to_hash.slice("notice", "alert") }
      end

      def create
        if (user = User.find_by(email_address: params[:email_address]))
          PasswordsMailer.reset(user).deliver_later
        end

        redirect_to new_cp_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
      end

      def edit
        render inertia: "cp/auth/ResetPassword", props: { token: params[:token], flash: flash.to_hash.slice("notice", "alert") }
      end

      def update
        if @user.update(params.permit(:password, :password_confirmation))
          @user.sessions.destroy_all
          redirect_to new_cp_session_path, notice: "Password has been reset."
        else
          redirect_to edit_cp_password_path(params[:token]), alert: "Passwords did not match."
        end
      end

      private
        def set_user_by_token
          # Also accepts invitation links (Nibble::Cp::UsersController), which last longer than a reset link.
          @user = User.find_by_password_reset_token(params[:token]) || User.find_by_token_for(:invitation, params[:token])
          redirect_to new_cp_password_path, alert: "Password reset link is invalid or has expired." unless @user
        end
    end
  end
end
