# frozen_string_literal: true

describe 'External Token Sessions' do
  let(:secret) { 'test-external-token-secret' }
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account:, email: 'member@example.com') }

  around do |example|
    previous = ENV.fetch('EXTERNAL_TOKEN_AUTH_SECRET', nil)
    ENV['EXTERNAL_TOKEN_AUTH_SECRET'] = secret
    example.run
    ENV['EXTERNAL_TOKEN_AUTH_SECRET'] = previous
  end

  def build_token(payload = {}, key: secret)
    claims = {
      'email' => user.email,
      'exp' => 5.minutes.from_now.to_i,
      'jti' => SecureRandom.uuid
    }.merge(payload)

    JWT.encode(claims, key, 'HS256')
  end

  describe 'GET /auth/external_token' do
    it 'signs in an existing user and redirects to root' do
      get external_token_session_path(token: build_token)

      expect(response).to redirect_to(root_path)

      get root_path

      expect(response).to have_http_status(:ok)
    end

    it 'rejects an expired token' do
      token = build_token({ 'exp' => 5.minutes.ago.to_i })

      get external_token_session_path(token:)

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be_present
    end

    it 'rejects a token signed with the wrong key' do
      token = build_token({}, key: 'wrong-secret')

      get external_token_session_path(token:)

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects a replayed token' do
      token = build_token

      get external_token_session_path(token:)

      expect(response).to redirect_to(root_path)

      delete destroy_user_session_path

      get external_token_session_path(token:)

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects a token without a jti' do
      get external_token_session_path(token: build_token({ 'jti' => nil }))

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects an unknown email without the provision claim' do
      token = build_token({ 'email' => 'stranger@example.com' })

      expect do
        get external_token_session_path(token:)
      end.not_to change(User, :count)

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'provisions a new user when the provision claim is set' do
      token = build_token({ 'email' => 'newcomer@example.com',
                            'provision' => true,
                            'first_name' => 'New',
                            'last_name' => 'Comer' })

      expect do
        get external_token_session_path(token:)
      end.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)

      new_user = User.find_by(email: 'newcomer@example.com')

      expect(new_user.account_id).to eq(account.id)
      expect(new_user.first_name).to eq('New')
    end

    it 'returns not found when the feature is not configured' do
      ENV['EXTERNAL_TOKEN_AUTH_SECRET'] = nil

      get external_token_session_path(token: build_token)

      expect(response).to have_http_status(:not_found)
    end
  end
end
