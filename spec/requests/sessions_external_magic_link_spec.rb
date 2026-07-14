# frozen_string_literal: true

describe 'Sessions External Magic Link' do
  let(:issuer_url) { 'https://issuer.example.com/api/sign/magic-link' }
  let(:account) { create(:account) }

  before do
    create(:user, account:)
  end

  around do |example|
    previous = ENV.fetch('EXTERNAL_MAGIC_LINK_ISSUER_URL', nil)
    ENV['EXTERNAL_MAGIC_LINK_ISSUER_URL'] = issuer_url
    example.run
    ENV['EXTERNAL_MAGIC_LINK_ISSUER_URL'] = previous
  end

  describe 'GET /sign_in' do
    it 'renders the magic link form posting to the issuer URL' do
      get new_user_session_path

      expect(response.body).to include('external_magic_link_form')
      expect(response.body).to include(issuer_url)
    end

    it 'renders the sent notice instead of the form after a request' do
      get new_user_session_path(magic_link_sent: 1)

      expect(response.body).to include('external_magic_link_sent')
      expect(response.body).not_to include('external_magic_link_form')
    end

    it 'renders no magic link markup when the issuer URL is not configured' do
      ENV['EXTERNAL_MAGIC_LINK_ISSUER_URL'] = nil

      get new_user_session_path

      expect(response.body).not_to include('external_magic_link')
    end
  end
end
