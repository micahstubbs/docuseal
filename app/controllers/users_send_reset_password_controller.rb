# frozen_string_literal: true

class UsersSendResetPasswordController < ApplicationController
  load_and_authorize_resource :user

  LIMIT_DURATION = 10.minutes

  def update
    authorize!(:manage, @user)

    if rate_limited?
      redirect_back fallback_location: settings_users_path, notice: I18n.t('email_has_been_sent_already')
    else
      @user.send_reset_password_instructions

      redirect_back fallback_location: settings_users_path,
                    notice: I18n.t('an_email_with_password_reset_instructions_has_been_sent')
    end
  end

  private

  # The rate limit only applies while the last email is recent AND the invitation
  # is still valid. Once the invitation token has expired (never accepted and older
  # than Devise.reset_password_within), allow an immediate resend so admins can
  # recover stuck invitations without waiting out the throttle.
  def rate_limited?
    return false if @user.reset_password_sent_at.blank?
    return false if @user.invitation_status == :expired

    @user.reset_password_sent_at > LIMIT_DURATION.ago
  end
end
