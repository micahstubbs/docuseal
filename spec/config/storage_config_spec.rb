# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/storage.yml' do
  let(:config) do
    raw = ERB.new(Rails.root.join('config/storage.yml').read).result
    YAML.safe_load(raw)
  end

  describe 'aws_s3 service' do
    # Regression: aws-sdk-s3 v3 sends CRC32 integrity checksums by default, which
    # S3-compatible providers (Cloudflare R2, MinIO, Backblaze B2) reject.
    # `when_required` restores compatibility without affecting AWS itself.
    it 'relaxes request checksum calculation for S3-compatible providers' do
      expect(config['aws_s3']['request_checksum_calculation']).to eq('when_required')
    end

    it 'relaxes response checksum validation for S3-compatible providers' do
      expect(config['aws_s3']['response_checksum_validation']).to eq('when_required')
    end
  end
end
