# Suite green, deploy, fork-network checklist

## Summary

Fixed the failing spec's root cause (docker test harness missing CI's asset-precompile
step), drove the full RSpec suite to green (337 examples, 0 failures, 6 pending),
deployed the merged master to sign.dataroom.fast, and produced the fork-network
feature checklist (implemented vs planned).

## Completed Work

- **docuseal-n9s** (`958ebd06`): `scripts/test-in-docker.sh` now mirrors CI — installs
  nodejs/yarn/chromium in the test container, runs `yarn install` +
  `NODE_ENV=test rake assets:precompile` during setup. The
  `email_smtp_settings_test_spec.rb:85` failure was Shakapacker's missing
  `public/packs-test/manifest.json`, never built in the container.
- **docuseal-rtl** (`54335c63`): full-suite failures fixed via /sd root-causing:
  - 24 webhook job spec failures: specs asserted upstream's hardcoded
    `'DocuSeal.com Webhook'` UA, but the white-label commit made
    `SendWebhookRequest::USER_AGENT` derive from `Docuseal::PRODUCT_NAME`. Specs now
    reference the constant; `SendTestWebhookRequestJob::USER_AGENT` aligned too.
  - 2 preserved-order completion job specs: the suite-level
    `Submissions.maybe_update_completed_at` hook runs before `let!(:next_submitter)`
    exists, wrongly stamping the submission completed; then
    `GenerateResultAttachments.single_sign_reason` crashed sorting a nil
    `completed_at`. Spec now clears the stamp — key detail: the stamp comes from
    `update_all`, so the in-memory object still had nil and a plain
    `update!(completed_at: nil)` was a silent no-op; `reload.update!` required.
  - 1 multitenant preview spec: Disk service needs
    `ActiveStorage::Current.url_options` outside a request cycle.
  - 4 setup system specs: leaked users/accounts in the container's test DB (from a
    prior non-transactional run); recreated `docuseal_test` fresh.
  - Full suite: **337 examples, 0 failures, 6 pending** (pre-existing skips).
- **Deploy**: rebuilt `dataroom-sign:latest` (`1f2e6259`) from master incl. all merged
  work; swapped container (old kept as `dataroom-sign-old-20260713` for rollback;
  same config: port 127.0.0.1:3102, volume dataroom-sign-data, FORCE_SSL). Health:
  200 local + 200 via https://sign.dataroom.fast; /hss screenshot verified landing
  page, attribution links, and documents counter (data volume intact).
- **docuseal-gaf** (`4a1b9e29`): `docs/fork-network-feature-checklist.md` — Tier 1
  10/10 done; Tier 2 3/5 (open: sync-upstream discipline docuseal-7wq, Docker CI
  docuseal-cw3); Tier 3 9 done, 15 open; Tier 4 0/12 all licensing-gated. Audit found
  closed issue docuseal-siv over-claimed i18n auto-detect + form language switcher —
  not in the code; reopened as **docuseal-iy3**.

## Pending / Blocked

- docuseal-t10: visual verify Documents view + dark mode (needs authenticated session).
- Old container `dataroom-sign-old-20260713` (stopped) can be removed by the user
  once the new deploy has soaked.
- Open fork-network work: see checklist doc; Tier 4 items each need a licensing
  go/no-go per docs/licensing/pro-feature-reimplementation-memo.md.

## Next Session Context

- master `54335c63` deployed and pushed; suite green in docker harness.
- Test containers (docuseal-test-app/pg) left running with gems+assets warm.
