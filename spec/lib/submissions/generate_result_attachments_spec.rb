# frozen_string_literal: true

RSpec.describe Submissions::GenerateResultAttachments do
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

  def extract_texts(attachment)
    pdf = HexaPDF::Document.new(io: StringIO.new(attachment.download))

    pdf.pages.map do |page|
      text = +''

      processor = Class.new(HexaPDF::Content::Processor) do
        define_method(:show_text) { |str| text << decode_text(str) }
        alias_method :show_text_with_positioning, :show_text
      end.new

      page.process_contents(processor)

      text
    end
  end

  describe 'completion watermark' do
    it 'stamps document id, completion timestamp and pre-stamp SHA-256 hash on every page by default' do
      attachments = described_class.call(submitter)
      document = attachments.find { |a| a.name == 'documents' }

      watermark_sha256 = document.metadata['watermark_sha256']

      expect(watermark_sha256).to match(/\A[0-9a-f]{64}\z/)

      document_id = Digest::MD5.hexdigest(submitter.submission.slug).upcase
      timestamp = submitter.completed_at.utc.strftime('%Y-%m-%d %H:%M:%S UTC')

      texts = extract_texts(document)

      expect(texts).not_to be_empty

      texts.each do |text|
        expect(text).to include("Document ID: #{document_id}")
        expect(text).to include("Completed: #{timestamp}")
        expect(text).to include("SHA-256: #{watermark_sha256}")
      end
    end

    it 'does not stamp the watermark when the account config is disabled' do
      create(:account_config, account:, key: AccountConfig::WITH_COMPLETION_WATERMARK_KEY, value: false)

      attachments = described_class.call(submitter)
      document = attachments.find { |a| a.name == 'documents' }

      expect(document.metadata['watermark_sha256']).to be_nil

      texts = extract_texts(document)

      texts.each do |text|
        expect(text).not_to include('SHA-256:')
        expect(text).not_to include('Completed:')
      end
    end

    it 'stamps the watermark above the signature id stamp when both are enabled' do
      create(:account_config, account:, key: AccountConfig::WITH_SIGNATURE_ID, value: true)

      attachments = described_class.call(submitter)
      document = attachments.find { |a| a.name == 'documents' }

      watermark_sha256 = document.metadata['watermark_sha256']

      texts = extract_texts(document)

      texts.each do |text|
        expect(text).to include("SHA-256: #{watermark_sha256}")
        expect(text.scan('Document ID:').size).to be >= 2
      end
    end
  end
end
