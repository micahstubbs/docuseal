# frozen_string_literal: true

describe 'Account Configs' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before do
    sign_in(user)
  end

  describe 'POST /account_configs' do
    it 'saves the completion watermark toggle' do
      post account_configs_path,
           params: { account_config: { key: AccountConfig::WITH_COMPLETION_WATERMARK_KEY, value: '0' } }

      expect(response).to have_http_status(:ok)

      config = account.account_configs.find_by(key: AccountConfig::WITH_COMPLETION_WATERMARK_KEY)

      expect(config.value).to be(false)
    end

    it 'rejects keys outside the allowlist' do
      expect do
        post account_configs_path,
             params: { account_config: { key: 'unknown_key', value: '1' } }
      end.to raise_error(AccountConfigsController::InvalidKey)
    end
  end
end
