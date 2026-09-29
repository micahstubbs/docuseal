# frozen_string_literal: true

describe 'Submit Form signing-date fields default to today' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, only_field_types: %w[date]) }
  let(:submission) { create(:submission, :with_submitters, template:) }
  let(:submitter) { submission.submitters.first }
  let(:date_field) { submission.template_fields.find { |f| f['type'] == 'date' && f['submitter_uuid'] == submitter.uuid } }
  let(:today) { Time.current.in_time_zone(account.timezone).to_date.to_s }

  def form_values
    Nokogiri::HTML(response.body).at_css('submission-form')['data-values'].then { |v| JSON.parse(v) }
  end

  def rename_date_field(name)
    submission.update!(template_fields: submission.template_fields.map do |f|
      f['uuid'] == date_field['uuid'] ? f.merge('name' => name) : f
    end)
  end

  it "prefills a blank field named Date with today's date without saving it" do
    rename_date_field('Date')

    get submit_form_path(slug: submitter.slug)

    expect(response).to have_http_status(:ok)
    expect(form_values[date_field['uuid']]).to eq(today)
    expect(submitter.reload.values[date_field['uuid']]).to be_blank
  end

  it 'keeps a date the signer already entered' do
    rename_date_field('Date signed')
    submitter.update!(values: submitter.values.merge(date_field['uuid'] => '2026-01-02'))

    get submit_form_path(slug: submitter.slug)

    expect(form_values[date_field['uuid']]).to eq('2026-01-02')
  end

  it 'does not prefill a date field that is not a signing date' do
    get submit_form_path(slug: submitter.slug)

    expect(date_field['name']).to start_with('Birthday')
    expect(form_values[date_field['uuid']]).to be_blank
  end
end
