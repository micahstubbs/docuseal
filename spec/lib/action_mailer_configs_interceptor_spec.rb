# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActionMailerConfigsInterceptor do
  let(:message) { Mail::Message.new(from: 'original@example.com', to: 'to@example.com') }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(Docuseal).to receive(:demo?).and_return(false)
    allow(Rails.application.config.action_mailer).to receive(:delivery_method).and_return(:smtp)
  end

  describe '.delivering_email' do
    context 'when SMTP_FROM is not set' do
      # Regression: ENV.fetch('SMTP_FROM') raised KeyError on every delivery
      # when a deployer configured SMTP_ADDRESS without SMTP_FROM.
      it 'does not raise and keeps the original from address' do
        expect { described_class.delivering_email(message) }.not_to raise_error
        expect(message.from).to eq(['original@example.com'])
      end
    end

    context 'when SMTP_FROM is set to a bare email' do
      before { stub_const('ENV', ENV.to_h.merge('SMTP_FROM' => 'sender@example.com')) }

      it 'replaces the from address' do
        described_class.delivering_email(message)

        expect(message.from).to eq(['sender@example.com'])
      end
    end
  end
end
