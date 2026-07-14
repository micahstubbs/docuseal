# frozen_string_literal: true

RSpec.describe 'Documents Page' do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account:) }

  before do
    sign_in(user)
  end

  context 'when there are no documents' do
    it 'shows the empty state dropzone' do
      visit documents_path

      expect(page).to have_content('Documents')
      expect(page).to have_content('Upload a New Document')
    end
  end

  context 'when there are sent documents and drafts' do
    let!(:sent_template) { create(:template, account:, author: user) }
    let!(:draft_templates) { create_list(:template, 2, account:, author: user) }
    let!(:submission) do
      create(:submission, :with_submitters, template: sent_template, created_by_user: user)
    end

    before do
      visit documents_path
    end

    it 'shows submissions in the sent documents section' do
      expect(page).to have_content(sent_template.name)
      expect(page).to have_content(submission.submitters.first.name)
    end

    it 'shows templates without submissions in the drafts section' do
      expect(page).to have_content('Drafts')

      draft_templates.each do |template|
        expect(page).to have_content(template.name)
      end
    end

    it 'does not list templates with submissions among drafts' do
      # The sent template appears once (as a submission row), not again as a draft card
      expect(page).to have_text(sent_template.name, count: 1)
    end
  end

  context 'when there are folders' do
    let!(:folder) { create(:template_folder, account:, author: user) }
    let!(:folder_template) { create(:template, account:, author: user, folder:) }

    it 'shows folder cards linking to the folder documents view' do
      visit documents_path

      expect(page).to have_link(folder.name, href: documents_path(folder_id: folder.id))
    end

    it 'opens the folder within the documents view' do
      visit documents_path(folder_id: folder.id)

      expect(page).to have_content(folder.name)
      expect(page).to have_content(folder_template.name)
    end
  end
end
