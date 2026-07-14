# frozen_string_literal: true

class CreateExternalAuthNonces < ActiveRecord::Migration[8.0]
  def change
    create_table :external_auth_nonces do |t|
      t.string :jti, null: false, index: { unique: true }

      t.datetime :created_at, null: false
    end
  end
end
