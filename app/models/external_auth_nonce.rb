# frozen_string_literal: true

# == Schema Information
#
# Table name: external_auth_nonces
#
#  id         :bigint           not null, primary key
#  jti        :string           not null
#  created_at :datetime         not null
#
# Indexes
#
#  index_external_auth_nonces_on_jti  (jti) UNIQUE
#
class ExternalAuthNonce < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
end
