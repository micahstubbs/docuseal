# Session Summary: Completion Watermark (DocuSign Parity)

## Summary

Implemented a DocuSign-style completion watermark: every page of a completed,
signed document now gets a two-line footer with the Document ID, completion
timestamp (UTC), and the SHA-256 hash of the pre-stamp signed PDF bytes.
Default-on with an account-level toggle, and the stamped hash is recorded in
the Audit Trail for verification. Branch: `4p3/completion-watermark`.

## Completed Work

- **docuseal-4p3** (epic) — Completion watermark, DocuSign parity. Closed.
  - **docuseal-qib** (`7cb6dd72`) — Core stamping in
    `lib/submissions/generate_result_attachments.rb`: serialize filled PDF →
    SHA-256 → draw 2-line footer on every page (HexaPDF overlay canvas with
    white underlay, auto-scaled font) → store `watermark_sha256` in
    attachment metadata. Stamps only when all submitters have completed;
    idempotent via `trailer.info[:CompletionWatermark]`; stacks above the
    existing signature-ID stamp when both are enabled. TDD spec:
    `spec/lib/submissions/generate_result_attachments_spec.rb`.
  - **docuseal-696** (`efc8529f`) — `AccountConfig::WITH_COMPLETION_WATERMARK_KEY`
    (default on, disable by setting false), allowlisted in
    `AccountConfigsController`, toggle in E-Signature settings Preferences,
    i18n labels for en/es/it/fr/pt/de/nl. Request spec:
    `spec/requests/account_configs_spec.rb`.
  - **docuseal-d6i** (`c2625e56`) — Audit trail documents table shows
    "Stamped SHA-256" from `metadata['watermark_sha256']`. Spec:
    `spec/lib/submissions/generate_audit_trail_spec.rb`.
- Design doc: `docs/plans/2026-07-13-completion-watermark-design.md`
  (DocuSign research: envelope-ID page stamp + Certificate-of-Completion
  hash; user chose ID+timestamp+hash on every page bottom, pre-stamp hash,
  default-on toggle).
- Test infrastructure: `scripts/test-in-docker.sh` — host has no Ruby 4.0.5,
  so specs run in a `ruby:4.0.5-alpine` container (`docuseal-test-app`) with
  a `postgres:16-alpine` sidecar (`docuseal-test-pg`), mirroring CI.

## Verification

- All new specs pass; full non-system sweep (spec/lib, spec/jobs,
  spec/requests, spec/mailers): 113 examples, 22 failures — all 22 are
  pre-existing fork drift (webhook specs expect upstream UA
  `DocuSeal.com Webhook`; this fork sends `DocuSeal Webhook`).
- Visual verification: rendered stamped PDFs to PNG (default, and combined
  with signature-ID stamp — correct stacking, no overlap); audit trail PDF
  shows matching Stamped SHA-256; settings toggle screenshotted via
  Playwright with a seeded-session cookie against the production image with
  changed code volume-mounted (`docuseal-wm-verify` container, now stopped).

## Pending / Blocked

- `docuseal-wm-verify` container is stopped but not removed (delete guard);
  remove manually with `docker rm docuseal-wm-verify` if desired.
- Test containers `docuseal-test-app`/`docuseal-test-pg` left running for
  future spec runs (`scripts/test-in-docker.sh rspec ...`;
  `scripts/test-in-docker.sh down` to stop).
- Pre-existing webhook UA spec failures (fork drift) — could be fixed by
  updating specs to the fork's UA string; not in scope here.
- Detached-signature submissions (`generate_detached_signature_attachments`)
  intentionally skip the watermark (stamping would invalidate detached sigs).

## Next Session Context

- Watermark hash semantics: stamped hash covers the signed PDF bytes
  *before* the watermark is drawn (and before digital signing); the final
  file's own SHA-256 remains in `metadata['sha256']`. Verification story is
  stamp ↔ audit-trail match.
- Open issue docuseal-x41 (fork network research) remains.
