# frozen_string_literal: true

RSpec.describe 'Saved signing images', type: :system do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }

  def open_new_document(types: %w[signature initials], format: nil)
    template = create(:template, account:, author:, only_field_types: types)
    if format
      template.fields.find { |field| field['type'] == 'signature' }['preferences']['format'] = format
      template.save!
    end
    submission = create(:submission, :with_submitters, template:)
    submitter = submission.submitters.first
    submitter.update!(name: 'Jane Doe')
    visit submit_form_path(slug: submitter.slug)
    submitter
  end

  def saved_images(kind)
    page.evaluate_script("JSON.parse(localStorage.getItem('docuseal.saved-images.v1.#{kind}') || '[]')")
  end

  it 'saves typed signatures and initials separately and reuses them as new attachments on another document' do
    first = open_new_document
    expect(page).to have_no_css('[data-testid="saved-signatures"]')
    find('#type_text_button').click
    fill_in 'signature_text_input', with: 'Jane Doe'
    click_button 'next'

    expect(saved_images('signature').size).to eq(1)
    expect(saved_images('signature').first['name']).to eq('Jane Doe')
    expect(page).to have_no_css('[data-testid="saved-signatures"]')
    fill_in 'initials_text_input', with: 'JD'
    click_button 'Sign and Complete'
    expect(page).to have_content('Document has been signed!')
    expect(saved_images('initials').size).to eq(1)

    second = open_new_document
    expect(page).to have_content('Saved on this device')
    find('[data-testid="saved-signature-option"]').click
    click_button 'next'
    find('[data-testid="saved-signature-option"]').click
    click_button 'Sign and Complete'
    expect(page).to have_content('Document has been signed!')

    %w[Signature Initials].each do |name|
      uuid = field_value(second.reload, name)
      expect(uuid).to be_present
      expect(uuid).not_to eq(field_value(first.reload, name))
      expect(second.attachments.find_by(uuid:)).to be_present
    end
    expect(saved_images('signature').size).to eq(1)
    expect(saved_images('initials').size).to eq(1)

    open_new_document
    find('[data-testid="saved-signature-remove"]').click
    expect(page).to have_no_css('[data-testid="saved-signatures"]')
    expect(saved_images('signature')).to be_empty
    expect(saved_images('initials').size).to eq(1)
    page.refresh
    expect(page).to have_no_css('[data-testid="saved-signatures"]')
  end

  it 'retains the opt-out across documents and does not store an uploaded signature' do
    open_new_document(types: %w[signature])
    find('[data-testid="saved-signature-optout"]').uncheck
    find('input[type="file"]', visible: false).attach_file(Rails.root.join('spec/fixtures/sample-image.png'))
    click_button 'Sign and Complete'
    expect(page).to have_content('Document has been signed!')
    expect(saved_images('signature')).to be_empty

    open_new_document(types: %w[signature])
    expect(find('[data-testid="saved-signature-optout"]')).not_to be_checked
    expect(page).to have_no_css('[data-testid="saved-signatures"]')
  end

  it 'saves and reuses upload-only signatures through the dropzone' do
    open_new_document(types: %w[signature], format: 'upload')
    find('input[type="file"]', visible: false).attach_file(Rails.root.join('spec/fixtures/sample-image.png'))
    expect(page).to have_button('Reupload')
    click_button 'Sign and Complete'
    expect(page).to have_content('Document has been signed!')
    expect(saved_images('signature').size).to eq(1)

    submitter = open_new_document(types: %w[signature], format: 'upload')
    find('[data-testid="saved-signature-option"]').click
    expect(page).to have_button('Reupload')
    click_button 'Sign and Complete'
    expect(page).to have_content('Document has been signed!')
    expect(field_value(submitter.reload, 'Signature')).to be_present
  end

  it 'saves a drawn signature when its field is completed' do
    open_new_document(types: %w[signature])
    draw_canvas
    click_button 'Sign and Complete'
    expect(page).to have_content('Document has been signed!')
    expect(saved_images('signature').size).to eq(1)
  end
end
