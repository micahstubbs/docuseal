# frozen_string_literal: true

module Api
  class TemplatesPdfController < ApiBaseController
    load_and_authorize_resource :template, parent: false

    def create
      files = build_uploaded_files

      return render json: { error: 'documents is required' }, status: :unprocessable_content if files.blank?

      @template.account = current_account
      @template.author = current_user
      @template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])
      @template.name = params[:name].presence || File.basename(files.first.original_filename, '.*')
      @template.external_id = params[:external_id].presence
      @template.source = :api

      Templates.maybe_assign_access(@template)

      @template.save!

      documents, = Templates::CreateAttachments.call(@template, { files: }, extract_fields: true)
      schema = documents.map { |doc| { attachment_uuid: doc.uuid, name: doc.filename.base } }

      @template.fields = Templates::ProcessDocument.normalize_attachment_fields(@template, documents) if @template.fields.blank?

      @template.update!(schema:)

      WebhookUrls.enqueue_events(@template, 'template.created')

      SearchEntries.enqueue_reindex(@template)

      render json: Templates::SerializeForApi.call(@template, schema_documents: documents)
    rescue Templates::CreateAttachments::PdfEncrypted
      render json: { error: 'PDF is encrypted' }, status: :unprocessable_content
    end

    private

    def build_uploaded_files
      Array.wrap(params[:documents]).filter_map do |doc|
        data = doc[:file].to_s
        next if data.blank?

        tempfile = Tempfile.new
        tempfile.binmode
        tempfile.write(Base64.decode64(data))
        tempfile.rewind

        name = doc[:name].to_s.presence || 'document'
        name = "#{name}.pdf" unless name.downcase.end_with?('.pdf')

        ActionDispatch::Http::UploadedFile.new(tempfile:, filename: name, type: 'application/pdf')
      end
    end
  end
end
