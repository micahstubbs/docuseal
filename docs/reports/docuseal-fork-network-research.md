# DocuSeal Fork Network Research: Integrable Features

**Research Date:** 2026-07-13
**Upstream:** docusealco/docuseal (17,516 stars, 1,710 forks)
**Target:** micahstubbs/docuseal (tracks upstream master as of 2026-07-13, `08c97d21`)
**Method:** Full programmatic screen of all 1,710 forks via GitHub API (compare `ahead_by`/`behind_by` per fork), followed by 12 parallel deep-dive agents examining commits, patches, PRs, and READMEs of every fork meaningfully ahead of upstream. Raw screen data: `docs/reports/fork-screen-results.tsv`. Screen script: `scripts/fork-network-screen.sh`.

## Executive Summary

Of 1,710 forks, 384 had pushes after forking and roughly 60 are meaningfully ahead of upstream. Excluding a ~25-fork DevOps-workshop cohort, branding-only forks, and junk, about **20 forks contain substantive original work**. The portable material clusters into five groups:

1. **Small, clean fixes upstream lacks** — a Cloudflare R2 storage fix (2 lines), a sequential-signing notification stall fix (1 line), Devise brute-force lockout (config-only), an SMTP_FROM crash guard, implicit-TLS SMTP env toggles, a PDF preview quality bump, and an S3 expired-preview-URL fix. These are near-free wins.
2. **Well-tested, env-gated integrations** — paperless-ngx and Twenty CRM document archival (s256 fork, ~1,100 LOC of specs), and a CareerPlug-quality submission export service.
3. **Substantial features with professional test coverage** — CareerPlug's request-changes-on-completed-submission and generic pre-fill options layer (both deliberately genericized for public porting); developbob's pluggable field detection (27 passing specs); maximus-output's Documents unified view (the only fork feature with system specs).
4. **Fork-maintenance process tooling** — the standout meta-discovery. Deenyoro's overlay + self-healing patches + upstream fingerprint guards + daily sync canary, and wabolabs' fork-invariants CI guard + pre-push guard + sync discipline. Zero licensing risk, directly applicable to keeping this fork healthy against upstream churn.
5. **DocuSeal Pro reimplementations** — SAML/OIDC SSO, embedding, teams/RBAC, reminders, SMS, Stripe payments, bulk send, white-label. Widespread across forks, mostly untested AI-generated code, and all licensing-sensitive under DocuSeal's AGPL-3.0 + `LICENSE_ADDITIONAL_TERMS`. Flagged separately; each requires a deliberate decision.

**Cross-fork corroboration signal:** DOCX→PDF conversion (absent from OSS upstream, present in Pro) was independently built by at least three forks (CraigIG4, shoaibanjam, Audidat) — the most-demanded capability gap in the network. Automated email reminders were independently built by at least five forks.

---

## Tier 1 — Small clean fixes (trivial effort, high confidence, no licensing concerns)

| # | Fix | Source fork | Size | Verified absent upstream? |
|---|---|---|---|---|
| 1.1 | **Cloudflare R2 / MinIO / B2 S3 checksum compat** — `request_checksum_calculation: when_required` + `response_checksum_validation: when_required` under `aws_s3.upload` in `config/storage.yml`. Fixes aws-sdk-ruby v3 CRC32 checksums breaking non-AWS S3 endpoints. | s24407-pj (`54395568fe`) | 2 lines | Yes |
| 1.2 | **Next-signer notification stall fix** — in `process_submitter_completion_job.rb`, preserved-order branch: `sub.completed_at.blank? && sub.sent_at.blank?` → `sub.completed_at.blank?`. A later submitter with `sent_at` stamped but incomplete stalls the sequential chain. **Caveat:** verify `Submitters.send_signature_requests` idempotency first (duplicate-invitation risk). | usehelloai (`0d2a9a4faf`) | 1 line | Yes |
| 1.3 | **Devise `:lockable` brute-force protection** — DB columns already exist upstream; the config block is commented out, so `/users/sign_in` has no lockout today. Enable `lock_strategy = :failed_attempts` (10), `unlock_strategy = :both`, `unlock_in = 1.hour`. | vshaveyko | config-only | Yes |
| 1.4 | **`SMTP_FROM` KeyError guard** — `ActionMailerConfigsInterceptor` has an unguarded `ENV.fetch('SMTP_FROM')` that raises when unset. Add default. | docuseal-plus | ~2 lines | Yes (verified still unguarded) |
| 1.5 | **Implicit-TLS SMTP env toggles** — `ssl:`/`tls:` keys from `SMTP_ENABLE_SSL`/`SMTP_ENABLE_TLS` in production `smtp_settings` (port-465 providers). | shoaibanjam (`1e3df9add`) | 2 lines | Yes |
| 1.6 | **S3 expired-preview-URL fix** — swap preview `<img>` `.url(time:)` for `ActiveStorage::Blob.proxy_path` in `submissions/show` + `submit_form/show`. Do **not** take the fork's global `Attachment#url` override (defeats upstream CDN design). | jamierowe1994 (`30ae5a1ea`) | view-level | Yes (self-hosted S3 without `ACTIVE_STORAGE_PUBLIC`) |
| 1.7 | **PDF preview render quality** — `MAX_WIDTH` 1400→2200 (env-overridable `PAGE_MAX_WIDTH`), truecolor PNG instead of quantized palette. Fixes banded/blurry builder previews. Tradeoff: larger cached blobs. | vshaveyko | ~11 lines | Yes |
| 1.8 | **Email attribution duplicate-separator fix** in `_email_attribution.html.erb`. Verify still reproduces. | Intebec (`a39fd1b`) | −3 lines | Verify |
| 1.9 | **Bounded retry in `ProcessSubmitterCompletionJob`** — bare `rescue RecordNotUnique … retry` → MAX 5 attempts with backoff; remove hardcoded `max_retries = 13` in `sidekiq_embed.rb`. **Verify against current upstream first** (agent hit rate limit mid-check). | docuseal-plus | ~30 lines | Needs verification |
| 1.10 | **Bundled optional extra:** Sidekiq `death_handlers` logging of exhausted-retry jobs. | usehelloai | ~10 lines | Yes |

## Tier 2 — Fork-maintenance process tooling (zero licensing risk, directly relevant)

This fork tracks upstream and carries local changes — exactly the situation this tooling exists for.

- **2.1 Overlay/sync toolkit (Deenyoro/docuseal-sso — the pattern, not the SSO):**
  - `apply-overlay.sh`: new files via `rsync --ignore-existing` (collision aborts); Gemfile changes as idempotent marker-delimited `.append` blocks; modifications as patches.
  - `heal-patches.sh`: `git apply --check` → `--3way` re-anchor → fuzzy; regenerates drifted patches and pushes the refresh; only true conflicts fail loudly.
  - `upstream-fingerprints.txt`: `file::substring` anchors for upstream methods your overrides prepend/wrap — catches upstream renames that would silently disable a feature.
  - `sync-canary.sh` + daily GitHub Actions workflow: simulates the *next* upstream merge in a throwaway worktree, checks patches/fingerprints/collisions, opens/auto-closes a GitHub issue with findings — advance warning before a sync breaks.
- **2.2 Fork-invariants CI guard (wabolabs/wabosign):** `config/fork_invariants.yml` (declarative must_exist / must_not_exist / must_contain / forbidden_globally, each with a `why:`) + `bin/fork-check` (stdlib Ruby, exit 1 on violation) wired into CI. An upstream merge that deletes fork code or reverts a carried change fails the build instead of shipping silently.
- **2.3 Pre-push guard (wabolabs):** `.githooks/pre-push` refusing any push to a `docusealco/*` remote + `bin/install-push-guard` (also strips the upstream remote's push URL). Prevents the classic accidental push/PR to upstream.
- **2.4 Sync discipline (wabolabs + s24407-pj + acul021):** `bin/sync-upstream <tag>` with git `rerere` conflict caching; scheduled sync-PR workflow (daily cron, opens PR or fast-forwards); upstream tag mirroring for Docker versioning.
- **2.5 CI/Docker improvements:** GHCR publishing with versioned+latest tags (Baw-Appie, several), split Docker build (prebuild webpack assets once, native per-arch builds) + GHA layer caching (acul021), hardened supply chain reference (s256: cosign, SBOM, provenance, SHA-pinned actions).

## Tier 3 — Features with strong engineering quality (moderate effort; low licensing risk)

- **3.1 Request changes on a completed submission (CareerPlug, PRs #11/#39/#61):** author reopens a completed submission with a reason; `changes_requested_at` column, status rollback, submitter email, `form.changes_requested` webhook, PDF/audit regeneration on re-completion. ~380 LOC + ~500 LOC specs. Genuinely novel (no Pro equivalent). Port the self-contained API controller + column + mailer; re-derive the `submitter.rb` state hooks against current upstream; decouple from their iframe-auth concern.
- **3.2 Generic "Pre-fill Options" layer (CareerPlug, PRs #10/#12/#16):** semantic field-name slots (e.g. `employee_email`) mapped to field UUIDs, auto-populate on form open, submitter values never clobbered, cached. `lib/prefill/*` facade (~500 LOC lib + ~1,000 LOC specs incl. integration). Deliberately renamed from "ATS" to generic for public-repo porting. Lib ports near-verbatim; Vue dropdown + controller call-sites need re-anchoring.
- **3.3 Submission export service (CareerPlug, PRs #2/#8):** push submission state to a configurable external REST endpoint on submitter status change; rollup status + values + audit events in one payload. `ExportService` base/subclass pattern, `ExportLocation` model, 3 migrations, ~360 LOC specs. Overlaps existing webhooks — evaluate vs. extending webhook serializers.
- **3.4 paperless-ngx + Twenty CRM integrations (s256, PRs #13/#15/#16):** on completion, upload signed PDF + audit trail to paperless-ngx and/or Twenty CRM. Env-gated no-ops when unconfigured; only shared touch-point is a 4-line hook in the completion job; ~1,100 LOC of specs incl. integration tests and e2e compose. The best-tested code found in the entire network.
- **3.5 Pluggable field detection (developbob, PR #6):** split-button in builder — existing ML autodetect untouched, plus deploy-time algorithm profiles (Ruby plugin scripts or declarative YAML with anchor/absolute positioning). 27 passing specs. Caveats: memoize the per-page-load `Dir.glob`, and `Kernel#load` plugin dir must not be user-writable.
- **3.6 Documents unified view (maximus-output):** DocuSign-style single "Documents" page (folders → sent submissions → drafts) replacing the Templates/Submissions split; root redirect; the only fork feature with updated system specs + an efficiency-review pass. No Pro overlap.
- **3.7 DOCX→PDF conversion via LibreOffice (CraigIG4 pattern; corroborated by shoaibanjam, Audidat):** upstream OSS accepts DOCX content types but raises `InvalidFileType` — no `soffice` path exists. Adopt as a feature: `soffice --convert-to pdf` in `create_attachments.rb` with per-conversion `--env:UserInstallation` profile isolation (prevents the well-known lock-contention failure) + actionable error when LibreOffice is missing. Cost: LibreOffice+JRE in the Alpine image (~400MB+). *Note: this replicates a Pro/cloud capability — mild licensing consideration.*
- **3.8 Env-override config infra `DOCUSEAL_CONFIG_*` (developbob):** env-var overrides for account configs with `locked_by_env?` UI locking; well-tested; prerequisite for several other developbob features. Plus externalized SMTP/storage config (`lib/external_config.rb`) with read-only settings pages.
- **3.9 Env-driven boot seeding (vshaveyko):** idempotent initializer creating Account/admin/API token/APP_URL/webhook from `DOCUSEAL_*` env vars — replaces the manual `/setup` wizard for containerized deploys; resilient to missing DB.
- **3.10 Custom fonts (ipuppyyt):** upload fonts, use in builder + submission forms + generated PDFs. ~860 LOC; needs cleanup (junk files, migration timestamp, upload validation audit). Integration risk at `generate_result_attachments.rb`.
- **3.11 Dark mode toggle (maximus-output):** `docuseal-dark` DaisyUI theme + navbar toggle + localStorage persistence with pre-paint bootstrap. ~23 lines. ipuppyyt's `bg-white`→`bg-base-100` token discipline is the companion cleanup.
- **3.12 Confidential invite-only public forms (chsdocuseal):** template preference restricting the shared link to existing submitter emails. Re-derive against current `start_form_controller` (hot file).
- **3.13 Departments / team scoping (chsdocuseal B1-B7):** coherent department model + join tables + fail-closed CanCan scoping + backfill rake tasks. Zero tests, 469 behind — re-derivation project. Overlaps Pro roles (licensing flag on the role un-gating part).
- **3.14 Compliance trio (developbob B5/B6/B8):** IP allowlist per account (add self-lockout guard first), consent banner for signers (**must take PR #16+#19 together** — #16 alone is bypassable), auto-archive/data retention (**non-functional as shipped** — needs job bootstrap + idempotency). All zero-test; all need specs written during port.
- **3.15 Smaller picks:** Send-TEST-Email button on SMTP settings (docuseal-plus, self-contained); invitation status badges + resend with expired-throttle bypass (docuseal-plus); Quick Send modal (developbob); product-tour replay button (Intebec); MCP settings admin-gating (Intebec); i18n browser-language auto-detect + form language switcher (developbob); zh-CN locale (new985211 — complete: YAML + both Vue i18n files); Polish locale (s24407-pj); CSP nonce meta for Turbo (acul021 — no-op until CSP enabled, safe hardening).

## Tier 4 — Licensing-sensitive Pro reimplementations (deliberate decision required)

DocuSeal is AGPL-3.0 **plus** `LICENSE_ADDITIONAL_TERMS` (Section 7(b) additional terms; this repo carries both files). The forks below reimplement features DocuSeal sells (Pro/Enterprise). Two distinct concerns: (a) reimplementing paid functionality from public docs (positioning/ToS-gray, not obviously code-license-violating when written from scratch); (b) **removing attribution or Pro gates**, which cuts directly against the additional terms. Several forks also self-disclose their code as AI-generated and unaudited.

| Feature | Best implementation(s) | Quality | Notes |
|---|---|---|---|
| SAML SSO | Deenyoro (Authentik-hardened, CVE-safe ruby-saml ≥1.18.0 pin, overlay-packaged); maximus-output (has `Account.first` single-tenant wart) | Deenyoro clean but **untested vs live IdP** | Named paid feature |
| OIDC SSO | acul021 (PKCE, identity linking, domain allowlist, configurable role claim, force-SSO, auto-provision as viewer) | Most coherent SSO in the network | Named paid feature |
| force_sso_auth enforcement | Deenyoro (+56, fail-safe never-lock-out design) | Elegant | Low risk — enforces a setting upstream ships |
| Embedded builder/form | vshaveyko (JWT token auth, fail-closed scope concern, specs; static-asset shadowing of the Pro stub is the bypass mechanism); iancenry (bigger bundle) | vshaveyko is spec-covered | Paid feature; the shadowing trick is aggressive |
| Teams / RBAC / roles | Many (s256 34-file version broke 221 specs; acul021 team-folder permissions drops users.role NOT NULL; chsdocuseal departments) | All invasive, mostly untested | Pro "roles & permissions" |
| Automated reminders | docuseal-plus (flood guard: send-latest-only after downtime, 7-day staleness cap, event-based dedup) > s256 (queue visibility UI, skip button) > maximus-output (sidekiq-cron) | Reasonable but untested | Pro feature; upstream OSS ships the settings UI but no job |
| SMS invitations | wabolabs (4 providers — BulkVS/Twilio/VoIP.ms/SignalWire — real sending + request/system specs) > maximus-output (Twilio+Vonage, no gems) > Deenyoro (RingCentral) | wabolabs best | Pro feature |
| Stripe payments | maximus-output (checkout + invoice modes, hardening pass) ≈ iancenry | **Untested money paths** | Pro feature |
| Bulk send CSV/XLSX | maximus-output, iancenry | Untested | Pro feature |
| White-label / custom logo & brand | Intebec engine (883-LOC config-driven, must excise their proprietary licence kill-switch) > developbob (logo+brand+**attribution-when-personalized**) > s256 | Mixed | **developbob's v1.3.0 "Powered by DocuSeal footer appears exactly when white-labeled" is the licensing-respectful pattern; wabolabs' explicit "fork of DocuSeal" UI/email attribution is the other good citizen** |
| Template-creation APIs (HTML/PDF/DOCX) + one-off submission APIs | iancenry (best code quality in that fork; needs Node render dep) ≈ s256 (PDF only, 451-line API doc) | No tests | Paid API capabilities |
| DocuSign template import | iancenry (OAuth2 + tab-type field mapping, 322-LOC lib, cleanest non-trivial feature there) | Competent, untested | Not a Pro feature — competitive migration tool; DocuSign ToS applies |

**Do-not-port list:** CSRF `skip_before_action` on signing controllers (Baw-Appie — real vulnerability); TLS `VERIFY_NONE` (centrocopiado); attribution stripping (Baw-Appie, eljommys, meonkeys, powerlexx, disruptiverecords — AGPL additional-terms violation); Pro-gate placeholder stripping (developbob B1, iancenry F1, maximus-output ability grants) unless deliberately decided; ipuppyyt/XiaXia009 superseded or entangled variants.

**Already in upstream (no action):** template.updated/created/archived webhooks; pagy `.limit` API; native redact field rendering; `rails_storage_proxy` model routing; Dockerfile CVE currency; kkpan11's 2023 snapshot.

## Concepts worth remembering (no portable code)

Approval-matrix admin UI for signing chains (IGSIGN); counterparty memory / recent-recipients (IGSIGN); signing journey visualization (IGSIGN); per-party redaction visibility + with/without-redaction result variants (shoaibanjam); voice input + AI summarization step (amromedllc); admin reopen/edit + signer self-edit (amromedllc); flash→floating-toasts CSP-clean UX (lueroux); compare-and-swap complete-once idempotency (IGSIGN); phone-channel-agnostic invitation dispatch (centrocopiado); upstream phone-home audit (meonkeys / upstream issue #302).

## Fork index (substantive forks)

| Fork | Ahead/Behind | Character | Verdict |
|---|---|---|---|
| CareerPlug/docuseal | 230/840 | Professional ATS vendor; specs everywhere | Mine features (3.1-3.3) |
| s256/docuseal-with-some-pro-features | 31/131 | Honest disclaimered Pro clone + tested integrations | Port integrations (3.4); Pro parts = Tier 4 |
| developbob/docuseal | 41/213 | Devin-driven, versioned releases, bimodal test coverage, self-repaired corruption | Port infra + field detection; compliance trio with fixes |
| Deenyoro/docuseal-sso | 11/28 | Overlay-architecture SSO | **Adopt the sync tooling (2.1)**; SSO = Tier 4 |
| wabolabs/wabosign | 92/86 | Most mature fork-maintenance operation | **Adopt invariants+guards (2.2-2.4)**; SMS = Tier 4 |
| acul021/docuseal | 29/68 | Coherent OIDC SSO + team folder permissions | CI workflows now; SSO = Tier 4 |
| maximus-output/docuseal | 30/131 | Claude-driven Pro unlock + Documents reorg | Documents view + dark mode; Pro parts = Tier 4 |
| vshaveyko/docuseal | 14/28 | EHR embed, spec-covered, current | :lockable + preview quality + env seed now; embed = Tier 4 |
| iancenry/docuseal (OpenSeal) | 14/86 | 15-phase Pro clone, zero tests, good Ruby | DocuSign import; APIs = Tier 4 |
| EmonNayeem/chsdocuseal | 17/469 | Departments ACL, 3-day build, zero tests | Re-derivation candidate (3.12-3.13) |
| SpeedbitsInfinityTools/docuseal-plus | 21/449 | AI-assisted Pro clone, self-disclosed | Small fixes (1.4, 1.9, TEST email, invitation resend) |
| Intebec/intebec-docuseal | 56/13 | Commercial white-label engine, actively synced | Tour button + separator fix; engine = Tier 4 (excise licence code) |
| CraigIG4/IGSIGN | 175/197 | Legal-ops vertical | DOCX conversion pattern (3.7); concepts |
| jamierowe1994, shoaibanjam, usehelloai, s24407-pj, ipuppyyt, new985211, Baw-Appie, centrocopiado, amromedllc, lueroux, meonkeys | various | Verticals/rebrands with individual gems | Tier 1 fixes + selected features as listed |

## Recommended sequencing

1. **Epic A — Quick wins:** Tier 1 fixes (1.1-1.10). Each is an afternoon-scale, independently committable change with a regression test.
2. **Epic B — Fork-maintenance hardening:** Tier 2 tooling. Highest leverage for the long-term health of this fork; no licensing exposure.
3. **Epic C — Integrations & features:** selected Tier 3 items, each ported with tests (several sources ship none).
4. **Epic D — Pro-feature decisions:** Tier 4 items gated on an explicit licensing decision per feature. Given the additional-terms exposure, treat each as its own go/no-go.

---
*Generated by fork-network research session; deep-dive agent catalogs archived in session scratchpad (`fork-catalogs/`). Screen data: `docs/reports/fork-screen-results.tsv` (384 candidates compared), fork list: `docs/reports/fork-screen-forklist.jsonl`.*
