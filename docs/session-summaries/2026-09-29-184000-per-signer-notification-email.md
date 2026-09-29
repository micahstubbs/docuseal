# Per-signer "X signed" notification email to the sender

## Summary

The founder was not emailed when a counterparty signed a document he sent from
sign.dataroom.fast. Found the root cause in stock DocuSeal's completion-email rules,
added a per-signer notification to the fork, deployed it, pointed it at
micah@superradiant.ai, and verified delivery end to end through Resend.

## Root cause

- Stock `ProcessSubmitterCompletionJob#enqueue_completed_emails` sends the owner's
  `completed_email` only when the **whole submission** completes (`is_last`). In the
  Superradiant envelopes the founder countersigns last, so a counterparty's signature
  never triggers it. Eight `complete_form` events since 2026-09-09 (submitters 34, 32,
  46, 54, 60, 62, 73 and the founder's own 33) produced exactly one owner email
  (EmailEvent 6, 2026-09-09, for the one fully completed submission 18).
- The same method also skips everything when `submission.preferences['send_email'] ==
  false`. Every API envelope since 2026-09-10 is created with `send_email: false`
  (invitations go out by Gmail), so even a full completion would send nothing.
- The account's only user (the template author) is `micahstubbs@pm.me`, so the one
  stock email went there, not to micah@superradiant.ai.
- SMTP was fine: Resend SMTP config (from sign@dataroom.fast), all MailDeliveryJobs
  succeeded. No fork code had removed notifications; this is the upstream design.

## Completed Work

- **docuseal-mnb** (`bdbe5f98`): new account config
  `submitter_signed_notification_emails` (`AccountConfig::SUBMITTER_SIGNED_NOTIFICATION_EMAILS_KEY`).
  `ProcessSubmitterCompletionJob` enqueues
  `SubmitterMailer#submitter_signed_notification_email` to each address whenever a
  non-viewer signer completes, regardless of the submission `send_email` flag; only when
  the CompletedSubmitter row is first created (no duplicates on retry); skips a recipient
  who is the signer. Email: subject `<Name> signed "<document>"` (or `... - all parties
  have signed`), body names signer and email, time in the account timezone, who is still
  pending, and the submission link. New en i18n keys, mailer preview, job spec (3 cases +
  not-configured case) and a mailer spec. New specs failed without the change.
- `f4de714e`: listed the changed files in `Dockerfile.patch` (the full Docker build is
  broken: pdfium release 404, docuseal-q1d).
- `91649f87`: `scripts/e2e-signed-notification.py`, the end-to-end check.

## Deploy

- Image `dataroom-sign:mnb` = `Dockerfile.patch` on `dataroom-sign:ok9` (keeps the
  concurrent CSRF fix docuseal-ok9). Rollback image tag `dataroom-sign:rollback-pre-mnb-20260929`.
- Waited for 3 quiet minutes of signing traffic (founder signed submissions 44/45 at 18:30Z).
- `scripts/redeploy-dataroom-sign.sh dataroom-sign:mnb`: old container stopped
  2026-09-29T18:33:46Z (kept as `dataroom-sign-old-20260929-113346`), new one started
  18:33:49Z, healthy 3 s later; https://sign.dataroom.fast/up 200.
- Production config (rails runner, 18:33:58Z): AccountConfig id 2
  `submitter_signed_notification_emails = micah@superradiant.ai`.
- The CSRF agent later redeployed on top of `dataroom-sign:mnb` (docuseal-svp); master
  holds both changes.

## Verification

- Specs (isolated containers docuseal-mnb-app/pg on the worktree): mailer + completion job
  + forms request specs, 14 examples, 0 failures; spec/jobs + spec/requests 138 examples,
  the only failures were environmental (no Shakapacker packs, missing fonts in that
  container; the two vips-font ones pass after adding fonts).
- E2E: `scripts/e2e-signed-notification.py` created template 47 and submission 48
  (`send_email: false`, Signer micah+signtest@superradiant.ai, Founder
  micah@superradiant.ai), completed only the Signer through `PUT /s/<slug>` (200), and
  found Resend email `01a0ee73-c1fe-76d4-9833-bfba5b0279ed` from sign@dataroom.fast to
  micah@superradiant.ai, `last_event: delivered`. EmailEvent 13 is the only email in the
  window. Template 47 / submission 48 archived; a stray first-attempt template 46 (no
  fields, no submission) archived too. No existing submission was touched.

## Pending/Blocked

- None for this feature. The address is set only by rails runner (no settings UI yet);
  change it with
  `docker exec -w /app dataroom-sign bin/rails runner "AccountConfig.find_by(account_id: 1, key: 'submitter_signed_notification_emails').update!(value: 'a@x, b@y')"`.
- Full `docker build` stays broken until docuseal-q1d is fixed.

## Next Session Context

- Worktree `~/wk/docuseal-worktrees/signed-notify` (branch `docuseal-mnb/signed-notify-email`)
  was used to stay clear of the concurrent CSRF session in `~/wk/docuseal`.
- A settings-page field for the address would need the notifications system spec to
  scope its `account_config[value]` lookups (two forms would share that field name).
