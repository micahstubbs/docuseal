# Signing form CSRF race fix and patch-layer deploy

## Summary
Fixed "Value is invalid" on sign.dataroom.fast signing forms (founder report, 2026-09-29). Root cause: concurrent first page loads created competing sessions, so the CSRF token went stale.

## Completed Work
- a1567002: regression spec (forgery protection on, stale token) in spec/requests/forms_spec.rb (docuseal-ok9)
- ccc5c993: skip CSRF on SubmitFormController#update; the slug is the credential (docuseal-ok9)
- Dockerfile.patch + scripts/redeploy-dataroom-sign.sh: code-only deploys while the full build is broken
- Deployed dataroom-sign:ok9 at 2026-09-29T18:27:30Z; old container kept stopped as dataroom-sign-old-20260929-112728

## Verification
- spec/requests: 58 examples, 0 failures; spec/system/signing_form_spec.rb: 48 examples, 0 failures (docker harness)
- Production probe on a throwaway submission: cookie+token, token only and cookie only all 200 (before the fix, 200/422/422)

## Pending/Blocked
- docuseal-q1d: full `docker build .` fails; the pinned pdfium release returns 404
- Test harness: libpdfium copied from the prod image into docuseal-test-app (setup's wget fails for the same reason)

## Next Session Context
Base patch builds on dataroom-sign:ok9 (or later) so this fix is kept. A concurrent agent is adding completion-notification emails in this repo.
