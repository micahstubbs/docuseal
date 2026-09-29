# frozen_string_literal: true

describe 'Submit Form' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, submitter_count: 2, only_field_types: %w[text]) }
  let(:viewer_uuid) { template.submitters.second['uuid'] }
  let(:submission) do
    create(:submission, :with_submitters, template:).tap do |s|
      s.update!(template_submitters: s.template_submitters.map do |ts|
        ts['uuid'] == viewer_uuid ? ts.merge('is_viewer' => true) : ts
      end)
    end
  end
  let(:viewer) { submission.submitters.find { |e| e.uuid == viewer_uuid } }

  describe 'PUT /s/:slug' do
    it 'blocks form submission for a view-only party' do
      put submit_form_path(slug: viewer.slug), params: { completed: 'true' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq(I18n.t('form_is_view_only'))
    end

    # Regression: two signing links opened at once in a fresh browser each start a
    # session; the later Set-Cookie replaces the earlier one, so the first tab's CSRF
    # token no longer matches and every submit from it failed with 422 ("Value is
    # invalid"). The slug is the credential for this form, so CSRF is not required.
    context 'with forgery protection enabled and a stale or missing CSRF token' do
      around do |example|
        original = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        example.run
      ensure
        ActionController::Base.allow_forgery_protection = original
      end

      let(:signer) { submission.submitters.find { |e| e.uuid != viewer_uuid } }

      it 'accepts the signer submission' do
        put submit_form_path(slug: signer.slug), params: { authenticity_token: 'stale-token-from-another-session' }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
