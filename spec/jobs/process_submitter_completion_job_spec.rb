# frozen_string_literal: true

RSpec.describe ProcessSubmitterCompletionJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user) }
  let(:submitter) { create(:submitter, submission:, uuid: SecureRandom.uuid, completed_at: Time.current) }

  before do
    create(:encrypted_config, key: EncryptedConfig::ESIGN_CERTS_KEY,
                              value: GenerateCertificate.call.transform_values(&:to_pem))

    Submissions.maybe_update_completed_at(submitter.submission)
  end

  describe '#perform' do
    it 'creates a completed submitter' do
      expect do
        described_class.new.perform('submitter_id' => submitter.id)
      end.to change(CompletedSubmitter, :count).by(1)

      completed_submitter = CompletedSubmitter.last
      submitter.reload

      expect(completed_submitter.submitter_id).to eq(submitter.id)
      expect(completed_submitter.submission_id).to eq(submitter.submission_id)
      expect(completed_submitter.account_id).to eq(submitter.submission.account_id)
      expect(completed_submitter.template_id).to eq(submitter.submission.template_id)
      expect(completed_submitter.source).to eq(submitter.submission.source)
    end

    it 'creates a completed document' do
      expect do
        described_class.new.perform('submitter_id' => submitter.id)
      end.to change(CompletedDocument, :count).by(1)

      completed_document = CompletedDocument.last

      expect(completed_document.submitter_id).to eq(submitter.id)
      expect(completed_document.sha256).to be_present
      expect(completed_document.sha256).to eq(submitter.documents.first.metadata['sha256'])
    end

    it 'raises an error if the submitter is not found' do
      expect do
        described_class.new.perform('submitter_id' => 'invalid_id')
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when submitters order is preserved' do
      let(:template) { create(:template, account:, author: user, submitter_count: 2) }
      let(:submission) do
        create(:submission, template:, created_by_user: user, submitters_order: 'preserved')
      end
      let(:submitter) do
        create(:submitter, submission:, uuid: submission.template_submitters.first['uuid'],
                           completed_at: Time.current)
      end

      let!(:next_submitter) do
        create(:submitter, submission:, uuid: submission.template_submitters.second['uuid'],
                           email: 'next@example.com')
      end

      before { SendSubmitterInvitationEmailJob.jobs.clear }

      it 'notifies the next incomplete submitter' do
        described_class.new.perform('submitter_id' => submitter.id)

        submitter_ids = SendSubmitterInvitationEmailJob.jobs.map { |j| j['args'].first['submitter_id'] }

        expect(submitter_ids).to include(next_submitter.id)
      end

      # Regression: the next-submitter lookup required sent_at to be blank, so a
      # pending submitter who had already been sent an invitation out-of-band was
      # skipped and the sequential chain stalled (or a later party was notified
      # out of order).
      it 'notifies the next incomplete submitter even when sent_at is already set' do
        next_submitter.update!(sent_at: 1.day.ago)

        described_class.new.perform('submitter_id' => submitter.id)

        submitter_ids = SendSubmitterInvitationEmailJob.jobs.map { |j| j['args'].first['submitter_id'] }

        expect(submitter_ids).to include(next_submitter.id)
      end
    end
  end
end
