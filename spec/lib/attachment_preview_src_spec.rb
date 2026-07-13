# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActiveStorage::Attachment#preview_src' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:attachment) { template.documents.first }

  # Regression: preview images were rendered with presigned service URLs that
  # expire (PRESIGNED_URLS_EXPIRE_MINUTES, default 4h), so long-open or cached
  # pages showed broken previews on self-hosted private storage.
  context 'when self-hosted with private storage' do
    before do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(attachment.blob.service).to receive(:public?).and_return(false)
    end

    it 'returns a non-expiring blob proxy path' do
      expect(attachment.preview_src).to start_with('/file/')
    end
  end

  context 'when multitenant' do
    before { allow(Docuseal).to receive(:multitenant?).and_return(true) }

    it 'returns the direct service url' do
      expect(attachment.preview_src).not_to start_with('/file/')
    end
  end
end
