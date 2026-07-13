# frozen_string_literal: true

require 'rails_helper'

# Regression: the sign-in endpoint is publicly exposed on self-hosted deploys;
# an explicit lockable policy (10 attempts, unlock by email or 1 hour) protects
# against credential brute-forcing. Columns and the model `:lockable` module
# were already present; this pins the configuration.
RSpec.describe 'Devise lockable configuration' do
  it 'locks accounts by failed attempts' do
    expect(Devise.lock_strategy).to eq(:failed_attempts)
  end

  it 'locks after 10 failed attempts by default' do
    expect(Devise.maximum_attempts).to eq(10)
  end

  it 'unlocks by email or after an hour' do
    expect(Devise.unlock_strategy).to eq(:both)
    expect(Devise.unlock_in).to eq(1.hour)
  end

  it 'includes lockable on the User model with required columns' do
    expect(User.devise_modules).to include(:lockable)
    expect(User.column_names).to include('failed_attempts', 'locked_at', 'unlock_token')
  end
end
