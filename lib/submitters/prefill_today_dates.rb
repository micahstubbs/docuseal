# frozen_string_literal: true

module Submitters
  # Prefills the signer's blank, editable signing-date fields with today's date in the
  # account timezone when the signing form is shown. The value is set in memory only and
  # is stored when the signer submits the step, so opening the form on a later day shows
  # that day. Only fields that name a signing date (or have no name) qualify; other date
  # fields such as a birthday or an expiry date, read-only fields and fields with a
  # template default are left alone.
  module PrefillTodayDates
    SIGNING_DATE_NAME = /\A\s*(date|date signed|signed date|signing date|signature date|signed on|today|today's date)?\s*\z/i

    module_function

    def call(submitter)
      fields = submitter.submission.template_fields || submitter.submission.template.fields

      fields.each do |field|
        next if field['type'] != 'date' || field['submitter_uuid'] != submitter.uuid
        next unless field['name'].to_s.match?(SIGNING_DATE_NAME)
        next if field['readonly'] == true || field['default_value'].present?
        next if submitter.values[field['uuid']].present?

        submitter.values[field['uuid']] =
          TimeUtils.current_date_value(field.dig('preferences', 'format'), submitter.account.timezone)
      end

      submitter
    end
  end
end
