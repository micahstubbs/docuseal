# frozen_string_literal: true

describe User do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  describe '#invitation_status' do
    it 'returns :accepted when the user has signed in at least once' do
      user.update!(sign_in_count: 1, reset_password_sent_at: 10.days.ago)

      expect(user.invitation_status).to eq(:accepted)
    end

    it 'returns :pending when the invitation email is still valid' do
      user.update!(sign_in_count: 0, reset_password_sent_at: 1.hour.ago)

      expect(user.invitation_status).to eq(:pending)
    end

    it 'returns :expired when the invitation email is older than the reset password window' do
      user.update!(sign_in_count: 0, reset_password_sent_at: (Devise.reset_password_within + 1.minute).ago)

      expect(user.invitation_status).to eq(:expired)
    end

    it 'returns :expired when no invitation email was sent' do
      user.update!(sign_in_count: 0, reset_password_sent_at: nil)

      expect(user.invitation_status).to eq(:expired)
    end
  end

  describe '#invitation_expires_at' do
    it 'returns nil when no invitation email was sent' do
      user.update!(reset_password_sent_at: nil)

      expect(user.invitation_expires_at).to be_nil
    end

    it 'returns the reset password deadline' do
      sent_at = Time.zone.parse('2026-07-01 12:00:00')

      user.update!(reset_password_sent_at: sent_at)

      expect(user.invitation_expires_at).to eq(sent_at + Devise.reset_password_within)
    end
  end
end
