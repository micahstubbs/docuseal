# Fork-Network Feature Checklist

Single source of truth for which fork-network features are **implemented in this
repo** and which are **planned but not yet implemented**. Derived from the research
report (`docs/reports/docuseal-fork-network-research.md`), the licensing memo
(`docs/licensing/pro-feature-reimplementation-memo.md`), commit history, and beads.
Status is verified against code, not against issue text.

Legend: `[x]` implemented (commit on master) · `[ ]` not implemented (beads key = tracking issue)

## Tier 1 — Quick-win fixes (COMPLETE: 10/10)

- [x] 1.1 Cloudflare R2 / MinIO / B2 S3 checksum compat — docuseal-pho, `a75cd1b3`
- [x] 1.2 Next-signer notification stall fix — docuseal-dtn, `ea0e2030`
- [x] 1.3 Devise `:lockable` brute-force protection — docuseal-ml1, `ebf0a12d`
- [x] 1.4 `SMTP_FROM` KeyError guard — docuseal-y35, `3cbf984a`
- [x] 1.5 Implicit-TLS SMTP env toggles (`SMTP_ENABLE_SSL`/`SMTP_ENABLE_TLS`) — docuseal-3na, `548bea16`
- [x] 1.6 S3 expired-preview-URL fix (blob proxy in views) — docuseal-8bt, `d0d6f257`
- [x] 1.7 PDF preview render quality (`PAGE_MAX_WIDTH`, truecolor) — docuseal-lb2, `ad9acc70`
- [x] 1.8 Email attribution separator/footer fix — docuseal-i9s, `184cfd29`
- [x] 1.9 Bounded `RecordNotUnique` retry + env `max_retries` — docuseal-ur1, `e7a9320c`
- [x] 1.10 Sidekiq `death_handlers` exhausted-retry logging — docuseal-6np, `02d5245c`

## Tier 2 — Fork-maintenance hardening (3/5)

- [x] 2.1 Overlay / heal-patches / upstream-fingerprints / sync-canary toolkit — docuseal-qd2, `a6785e53` (guard fix `14e6dcf2`)
- [x] 2.2 Fork-invariants CI guard (`config/fork_invariants.yml` + `bin/fork-check`) — docuseal-qkq, `bf76d50d`, extended `6c4a1daa`
- [x] 2.3 Pre-push guard against docusealco upstream — docuseal-k2y, `0ff17c8d`
- [ ] 2.4 Sync-upstream discipline (rerere script, scheduled sync PR, tag mirror) — **docuseal-7wq**
- [ ] 2.5 Docker CI improvements (GHCR publishing, split webpack/native build, layer caching) — **docuseal-cw3**

## Tier 3 — Integrations & features (9 implemented)

Implemented:

- [x] 3.4 paperless-ngx completed-document archival — docuseal-v3r, `8d961cd9`
- [x] 3.4 Twenty CRM signed-document upload — docuseal-v5t, `991407df`
- [x] 3.6 Documents unified view (behind `DOCUSEAL_DOCUMENTS_HOME`) — docuseal-36y, `58c379ef` *(code merged; visual verification pending — docuseal-t10)*
- [x] 3.11 Dark mode toggle (`docuseal-dark` DaisyUI theme) — docuseal-31g, `2250525d` *(code merged; visual verification pending — docuseal-t10)*
- [x] 3.15 Quick Send modal — docuseal-8xy, `54161c1b`
- [x] 3.15 Invitation status badges + expired-invite resend — docuseal-aqh, `03b5f4e3`
- [x] 3.15 Send Test Email button on SMTP settings — docuseal-wwt, `aded9691`
- [x] 3.15 Product Tour replay button — docuseal-siv, `cf59c05f`
- [x] 3.15 CSP nonce meta for Turbo — docuseal-siv, `e8e1f19a`

Not yet implemented:

- [ ] 3.1 Request changes on completed submission (CareerPlug) — **docuseal-q7f**
- [ ] 3.2 Generic Pre-fill Options layer (CareerPlug) — **docuseal-0np**
- [ ] 3.3 Submission export service (CareerPlug) — **docuseal-5sa**
- [ ] 3.5 Pluggable field detection (developbob) — **docuseal-xvp**
- [ ] 3.7 DOCX→PDF conversion via LibreOffice — **docuseal-5uw**
- [ ] 3.8 `DOCUSEAL_CONFIG_*` env-override config infra — **docuseal-z3q**
- [ ] 3.9 Env-driven boot seeding initializer — **docuseal-4je**
- [ ] 3.10 Custom fonts — **docuseal-1lw**
- [ ] 3.12 Confidential invite-only public forms — **docuseal-h1b**
- [ ] 3.13 Departments / team scoping — see gated docuseal-t0t (Tier 4 overlap)
- [ ] 3.14 IP allowlist per account — **docuseal-ho9**
- [ ] 3.14 Signer consent banner — **docuseal-8c9**
- [ ] 3.14 Auto-archive / data retention — **docuseal-5fb**
- [ ] 3.15 zh-CN locale — **docuseal-1s7**
- [ ] 3.15 i18n browser-language auto-detect + form language switcher — **docuseal-iy3** *(closed issue docuseal-siv claimed this but it is not in the code)*

## Tier 4 — Licensing-gated Pro reimplementations (0 implemented; each needs explicit go/no-go)

See `docs/licensing/pro-feature-reimplementation-memo.md` (docuseal-zmj) before starting any of these.

- [ ] SAML SSO (Deenyoro) — **docuseal-6dd**
- [ ] OIDC SSO (acul021) — **docuseal-i9r**
- [ ] force_sso_auth enforcement — **docuseal-8ys**
- [ ] Embedded builder/form (vshaveyko JWT) — **docuseal-mqq**
- [ ] Teams / departments RBAC — **docuseal-t0t**
- [ ] Automated email reminders — **docuseal-4g4**
- [ ] SMS invitations (wabolabs) — **docuseal-z86**
- [ ] Stripe payments — **docuseal-dh4**
- [ ] Bulk send CSV/XLSX — **docuseal-4ty**
- [ ] White-label branding w/ attribution-when-personalized — **docuseal-3ry** *(partial: configurable product name shipped as docuseal-492, `21df2dce`)*
- [ ] Template-creation + one-off submission APIs — **docuseal-350** *(partial: `POST /api/templates/pdf` shipped, `d3a33f20`)*
- [ ] DocuSign template import — **docuseal-ve0**

## Fork-local features (not from the fork network)

- [x] Completion watermark (ID + timestamp + SHA-256) on signed documents — docuseal-qib/696/d6i, `9428548f`/`1f87a704`/`83640720`
- [x] Configurable white-label product name — docuseal-492, `21df2dce`
- [x] Templates-from-PDF API endpoint — `d3a33f20`
- [x] Docker test harness (`scripts/test-in-docker.sh`) with node/chromium + asset precompile

## Do-not-port list (deliberate exclusions)

CSRF `skip_before_action` on signing controllers (vulnerability); TLS `VERIFY_NONE`;
attribution stripping (AGPL additional-terms violation); Pro-gate placeholder
stripping unless deliberately decided per licensing memo.
