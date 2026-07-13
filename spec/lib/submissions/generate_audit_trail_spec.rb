# frozen_string_literal: true

RSpec.describe Submissions::GenerateAuditTrail do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user) }
  let(:submitter) do
    create(:submitter, submission:, uuid: SecureRandom.uuid, completed_at: Time.current)
  end

  before do
    create(:encrypted_config, key: EncryptedConfig::ESIGN_CERTS_KEY,
                              value: GenerateCertificate.call.transform_values(&:to_pem))

    Submissions.maybe_update_completed_at(submitter.submission)
  end

  def extract_text(attachment)
    pdf = HexaPDF::Document.new(io: StringIO.new(attachment.download))

    pdf.pages.map do |page|
      text = +''

      processor = Class.new(HexaPDF::Content::Processor) do
        define_method(:show_text) { |str| text << decode_text(str) }
        alias_method :show_text_with_positioning, :show_text
      end.new

      page.process_contents(processor)

      text
    end.join("\n")
  end

  it 'includes the stamped watermark SHA-256 hash for verification' do
    Submissions::EnsureResultGenerated.call(submitter)

    audit_trail = described_class.call(submission.reload)

    watermark_sha256 = submitter.documents.first.metadata['watermark_sha256']

    expect(watermark_sha256).to match(/\A[0-9a-f]{64}\z/)

    text = extract_text(audit_trail)

    expect(text).to include('Stamped SHA-256:')
    expect(text).to include(watermark_sha256)
  end
end
