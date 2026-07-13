# Completion Watermark (Timestamp + Document Hash) on Signed Documents

Feature parity target: DocuSign's post-signature per-page stamp. DocuSign stamps
`Envelope ID: <32-hex GUID>` on every page of a completed envelope (top-left by
default, admin-configurable), and records the SHA-256 document hash plus signing
timestamps in its Certificate of Completion. This feature goes one step further,
as requested: the ID, the completion timestamp, and the SHA-256 hash are all
stamped at the bottom of every page of every signed document.

## Decisions (confirmed with user)

1. **Content** — two footer lines on every page:
   - Line 1: `Document ID: <MD5-of-submission-slug> | Completed: <UTC timestamp>`
   - Line 2: `SHA-256: <64-char hex hash>`
2. **Hash target** — the completed, signed PDF bytes serialized *after* all
   fields are flattened but *before* the watermark is drawn (and before the
   PDF digital signature is applied, so the eSign cert stays valid).
   The same hash is stored in attachment metadata (`watermark_sha256`) and
   surfaced in the Audit Trail so the stamped value is independently
   verifiable against a trusted record.
3. **Toggle** — on by default for all accounts; new
   `AccountConfig::WITH_COMPLETION_WATERMARK_KEY = 'with_completion_watermark'`
   disables it when explicitly set to `false`. Toggle UI on the e-sign
   settings page, mirroring the existing `with_signature_id` toggle.
4. **Placement** — bottom of every page. When the existing signature-ID stamp
   (`with_signature_id`) is also enabled, the watermark stacks above it.

## Architecture

- **Stamping** happens in `Submissions::GenerateResultAttachments.build_pdf_attachment`
  (`lib/submissions/generate_result_attachments.rb:747`), before the
  sign/write branch:
  1. Serialize the filled PDF to a scratch `StringIO` (`validate: false`).
  2. `Digest::SHA256.hexdigest` those bytes.
  3. Draw the two footer lines on each page with the existing HexaPDF idiom
     (`page.canvas(type: :overlay)` + `TextFragment` with white underlay +
     `TextLayouter#fit#draw`), same auto-scaled font size as the
     signature-ID stamp (`min(page dims)/A4 width * 9`, floor 4).
  4. Continue with the existing sign/write path unchanged.
  5. Add `watermark_sha256: <hex>` to the attachment metadata.
- **Timestamp** — `submitter.completed_at` in UTC
  (`%Y-%m-%d %H:%M:%S UTC`). For the last submitter this is the submission
  completion time; intermediate per-submitter documents get that submitter's
  completion time (consistent with how the existing signature-ID stamp applies
  to every generation).
- **Config threading** — `WITH_COMPLETION_WATERMARK_KEY` added to the batch
  config query in `generate_pdfs`; `with_watermark = value != false`
  (default-on, same pattern as `FLATTEN_RESULT_PDF_KEY`). Passed to
  `build_pdf_attachment(with_watermark:, ...)`.
- **Audit trail** — `Submissions::GenerateAuditTrail` documents table gains a
  `stamped_sha256` row showing `metadata['watermark_sha256']` when present.
- **i18n** — stamp labels reuse `document_id`; new keys for `completed` label
  (if absent) and the settings toggle label/tooltip, added for all locales in
  `config/locales/i18n.yml`.

## Verification story

A recipient can verify integrity via the Audit Trail: the stamped SHA-256 must
match the `watermark_sha256` recorded there. (The hash cannot cover the final
byte stream that contains the stamp itself — stamping changes the bytes — so
the pre-stamp serialization is the canonical hashed artifact, and the post-stamp
`sha256` attachment metadata continues to identify the distributed file.)

## Testing

- New `spec/lib/submissions/generate_result_attachments_spec.rb`:
  - watermark present on every page by default (text extraction);
  - stamped hash equals SHA-256 of the pre-stamp serialization recorded in
    `metadata['watermark_sha256']`;
  - no watermark when the account config is set to `false`;
  - stacks above the signature-ID stamp when both are enabled.
- Audit-trail spec asserts the stamped hash row renders.
- Settings toggle covered in a request/system spec.
