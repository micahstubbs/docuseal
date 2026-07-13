# frozen_string_literal: true

describe 'Email SMTP Settings Test' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  let(:smtp_value) do
    {
      'host' => 'smtp.example.com',
      'port' => '587',
      'username' => 'user',
      'password' => 'secret',
      'authentication' => 'plain',
      'from_email' => 'noreply@example.com'
    }
  end

  before do
    sign_in(user)
  end

  describe 'POST /settings/email_test' do
    context 'when SMTP settings are configured' do
      before do
        create(:encrypted_config, account:, key: EncryptedConfig::EMAIL_SMTP_KEY, value: smtp_value)
      end

      it 'sends a test email via SMTP and redirects with a notice' do
        expect_any_instance_of(Mail::SMTP).to receive(:deliver!).and_return(true)

        post settings_email_test_index_path, params: { email: 'recipient@example.com' }

        expect(response).to redirect_to(settings_email_index_path)
        expect(flash[:notice]).to eq(I18n.t('test_email_has_been_sent_to', email: 'recipient@example.com'))
      end

      it 'builds the SMTP settings hash from the account encrypted config' do
        smtp_delivery = nil

        allow_any_instance_of(Mail::SMTP).to receive(:deliver!) do |instance|
          smtp_delivery = instance

          true
        end

        post settings_email_test_index_path, params: { email: 'recipient@example.com' }

        expect(smtp_delivery.settings).to include(address: 'smtp.example.com',
                                                  port: '587',
                                                  user_name: 'user',
                                                  password: 'secret',
                                                  authentication: 'plain')
      end

      it 'redirects with an alert when the recipient email is invalid' do
        expect_any_instance_of(Mail::SMTP).not_to receive(:deliver!)

        post settings_email_test_index_path, params: { email: 'not-an-email' }

        expect(response).to redirect_to(settings_email_index_path)
        expect(flash[:alert]).to eq(I18n.t('please_enter_a_valid_email_address'))
      end

      it 'redirects with an alert when the SMTP connection fails' do
        allow_any_instance_of(Mail::SMTP).to receive(:deliver!).and_raise(StandardError, 'connection refused')

        post settings_email_test_index_path, params: { email: 'recipient@example.com' }

        expect(response).to redirect_to(settings_email_index_path)
        expect(flash[:alert]).to eq(I18n.t('failed_to_send_test_email', error: 'connection refused'))
      end
    end

    context 'when SMTP settings are not configured' do
      it 'redirects with an alert' do
        post settings_email_test_index_path, params: { email: 'recipient@example.com' }

        expect(response).to redirect_to(settings_email_index_path)
        expect(flash[:alert]).to eq(I18n.t('please_configure_smtp_settings_first'))
      end
    end
  end

  describe 'GET /settings/email_test/new' do
    it 'renders the test email modal' do
      create(:encrypted_config, account:, key: EncryptedConfig::EMAIL_SMTP_KEY, value: smtp_value)

      get new_settings_email_test_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('send_test_email'))
    end
  end
end
