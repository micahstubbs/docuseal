# frozen_string_literal: true

# docuseal-mnb: per-signer notice to the sender.
RSpec.describe SubmitterMailer do
  describe '#submitter_signed_notification_email' do
    let(:account) { create(:account) }
    let(:user) { create(:user, account:) }
    let(:template) { create(:template, account:, author: user, submitter_count: 2, name: 'Advisor Agreement') }
    let(:submission) { create(:submission, template:, created_by_user: user) }
    let!(:signer) do
      create(:submitter, submission:, uuid: submission.template_submitters.first['uuid'],
                         name: 'Ada Lovelace', email: 'ada@example.com', completed_at: Time.current)
    end
    let!(:countersigner) do
      create(:submitter, submission:, uuid: submission.template_submitters.second['uuid'],
                         name: 'Founder Person', email: 'founder@example.com')
    end

    def body_of(mail)
      (mail.html_part || mail).body.decoded
    end

    it 'names the signer, the document, the pending signers and links the submission' do
      mail = described_class.submitter_signed_notification_email(signer, to: 'founder@example.com')

      expect(mail.to).to eq(['founder@example.com'])
      expect(mail.subject).to eq('Ada Lovelace signed "Advisor Agreement"')

      body = body_of(mail)

      expect(body).to include('Ada Lovelace (ada@example.com)')
      expect(body).to include('Advisor Agreement')
      expect(body).to include('Still waiting on: Founder Person')
      expect(body).to include("/submissions/#{submission.id}")
    end

    it 'says all parties have signed once nobody is pending' do
      countersigner.update!(completed_at: Time.current)

      mail = described_class.submitter_signed_notification_email(countersigner, to: 'owner@example.com')

      expect(mail.subject).to eq('Founder Person signed "Advisor Agreement" - all parties have signed')
      expect(body_of(mail)).to include('All parties have now signed.')
    end
  end
end
