# frozen_string_literal: true

# Signs a user in with a single-use, HMAC-signed token minted by an external
# issuer that shares the EXTERNAL_TOKEN_AUTH_SECRET value. The feature is off
# unless that env variable is set.
class ExternalTokenSessionsController < ApplicationController
  skip_before_action :maybe_redirect_to_setup
  skip_before_action :authenticate_user!
  skip_authorization_check

  REQUIRED_CLAIMS = %w[email exp jti].freeze

  def show
    return head :not_found if secret.blank?

    RateLimit.call("external-token-auth-#{request.remote_ip}", limit: 10, ttl: 1.minute, enabled: true)

    claims = decode_and_consume_token

    user = find_or_provision_user(claims) if claims

    if user.blank?
      return redirect_to new_user_session_path,
                         alert: I18n.t(:invalid_or_expired_sign_in_link,
                                       default: 'Invalid or expired sign-in link.')
    end

    sign_in(user)

    redirect_to root_path
  end

  private

  def secret
    ENV.fetch('EXTERNAL_TOKEN_AUTH_SECRET', nil)
  end

  def decode_and_consume_token
    claims, = JWT.decode(params[:token].to_s, secret, true,
                         algorithm: 'HS256', required_claims: REQUIRED_CLAIMS)

    return if claims['jti'].blank?

    ExternalAuthNonce.create!(jti: claims['jti'])

    claims
  rescue JWT::DecodeError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    nil
  end

  def find_or_provision_user(claims)
    email = claims['email'].to_s.downcase.strip

    user = User.active.find_by(email:)

    return user if user
    return unless claims['provision'] == true

    account = Account.order(:id).first

    return if account.blank?

    account.users.create(email:,
                         first_name: claims['first_name'].presence || email.split('@').first,
                         last_name: claims['last_name'].presence,
                         password: SecureRandom.hex(16)).then { |u| u if u.persisted? }
  end
end
