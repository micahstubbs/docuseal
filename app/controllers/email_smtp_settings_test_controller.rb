# frozen_string_literal: true

class EmailSmtpSettingsTestController < ApplicationController
  before_action :load_encrypted_config

  authorize_resource :encrypted_config, parent: false, only: %i[new create]

  def new; end

  def create
    if @encrypted_config.value.blank?
      return redirect_to settings_email_index_path, alert: I18n.t('please_configure_smtp_settings_first')
    end

    email = params[:email].to_s.strip

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to settings_email_index_path, alert: I18n.t('please_enter_a_valid_email_address')
    end

    from_email = @encrypted_config.value['from_email'] || current_user.email

    mail = SettingsMailer.smtp_test_email(email, from_email)

    # Force SMTP delivery to exercise the real connection (bypasses letter_opener in development)
    mail.delivery_method(:smtp, ActionMailerConfigsInterceptor.build_smtp_configs_hash(@encrypted_config))
    mail.deliver_now!

    redirect_to settings_email_index_path, notice: I18n.t('test_email_has_been_sent_to', email:)
  rescue StandardError => e
    redirect_to settings_email_index_path, alert: I18n.t('failed_to_send_test_email', error: e.message)
  end

  private

  def load_encrypted_config
    @encrypted_config =
      EncryptedConfig.find_or_initialize_by(account: current_account, key: EncryptedConfig::EMAIL_SMTP_KEY)
  end
end
