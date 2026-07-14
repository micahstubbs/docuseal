# Merge worktree branches to master

## Summary

Integrated the `fork-network-integrations` worktree with the main checkout and merged
both in-flight branches (`4p3/completion-watermark`, `worktree-fork-network-integrations`)
onto `master`, then pushed everything to origin. Beads issue: docuseal-hnr.

## Completed Work

- Detected that `origin/master` history had been rewritten (dataroom → docuseal rebrand
  purge); local `master` was a stale pre-rewrite tip (ahead 2556 / behind 2556).
  Preserved the old tip as local branch `master-pre-rewrite-2026-07-13` (NOT pushed —
  pushing would resurrect the purged pre-rewrite history) and moved `master` to
  `origin/master` via `git branch -f` (no reset --hard, per dcg guard).
- Fast-forwarded `4p3/completion-watermark` (13 commits: completion watermark toggle,
  stamped SHA-256 audit trail, templates PDF API, test-in-docker script) into master
  (`741273b0`).
- Merged `worktree-fork-network-integrations` (26 commits: Paperless/Twenty CRM upload
  integrations, Documents home, dark mode, quick send, SMTP test email, product-name
  white-label config, fork-invariants guard fix) into master — merge commit `d4c2013d`.
  The 5 files touched by both branches (account_config.rb, i18n.yml, routes.rb,
  generate_audit_trail.rb, generate_result_attachments.rb) auto-merged cleanly;
  verified additive (both branches' constants/routes/keys present, syntax OK).
- Beads reconcile: `br doctor` OK (61 records DB == JSONL), no rebuild needed.
- Verification: ran merged-code specs in the existing docker test containers
  (`scripts/test-in-docker.sh rspec`): 46 examples, 45 pass. The 1 failure
  (`email_smtp_settings_test_spec.rb:85`) is pre-existing/environmental — the view
  render needs `public/packs-test/manifest.json`, which has never been built in the
  test container; unrelated to the merge.
- Pushed `master` (`cf9f6f85..d4c2013d`) and `4p3/completion-watermark`
  (`dd080fc5..741273b0`) to origin.

## Key Changes

- `master` now contains both feature lines; merge commit `d4c2013d`.
- New local-only backup branch `master-pre-rewrite-2026-07-13` at `b7ee010b`.

## Pending / Blocked

- The email SMTP test-modal spec needs frontend assets compiled in the test container
  (node/yarn not installed in the ruby:4.0.5-alpine test image) to pass.
- Worktree at `.claude/worktrees/fork-network-integrations` left in place (branch fully
  merged; removal is user's call).

## Next Session Context

- Primary branch is `master` on the rewritten history; both feature branches are merged
  and can be deleted at the user's discretion.
