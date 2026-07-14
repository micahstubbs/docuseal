# frozen_string_literal: true

require 'sidekiq/web' if defined?(Puma)

if !ENV['SIDEKIQ_BASIC_AUTH_PASSWORD'].to_s.empty? && defined?(Sidekiq::Web)
  Sidekiq::Web.use(Rack::Auth::Basic) do |_, password|
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(password),
      Digest::SHA256.hexdigest(ENV.fetch('SIDEKIQ_BASIC_AUTH_PASSWORD'))
    )
  end
end

Sidekiq.strict_args!

Sidekiq.configure_server do |config|
  config.death_handlers << lambda { |job, exception|
    Rails.logger.error(
      "Sidekiq job died: #{job['class']} #{job['jid']} args=#{job['args'].inspect}: #{exception.message}"
    )

    Rollbar.error(exception, job_class: job['class'], jid: job['jid']) if defined?(Rollbar)
  }
end
