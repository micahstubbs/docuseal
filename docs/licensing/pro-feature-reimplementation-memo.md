# Decision Memo: Reimplementing DocuSeal Pro Features in This Fork

**Prepared for:** micahstubbs/docuseal (DocuSeal) — beads `docuseal-zmj`
**Status:** Draft for owner decision. Each Tier 4 item below is blocked in beads pending a per-feature go/no-go recorded here.

## 1. The actual license stack

This repository is licensed **AGPL-3.0** with one additional term under **AGPL §7(b)** (`LICENSE_ADDITIONAL_TERMS`, quoted in full):

> In accordance with Section 7(b) of the GNU Affero General Public License, a covered work must retain the original DocuSeal attribution in interactive user interfaces.

That is the entire additional-terms text. Notably, there is **no contractual anti-reimplementation clause** in the repository's license stack. Three distinct legal questions therefore govern Tier 4 work, and they are narrower than the fork community's folklore suggests:

### 1a. Attribution (the only express additional term)

Obligation: retain DocuSeal attribution in interactive UIs. **This fork already complies** — `app/views/shared/_powered_by.html.erb` keeps the "Powered by DocuSeal" link with an explicit §7(b) comment, the landing page links modified source per AGPL §13, and the email footer credits DocuSeal. Reimplementing features does not disturb this; *removing attribution does*. Several surveyed forks (Baw-Appie, eljommys, meonkeys, powerlexx, disruptiverecords) strip attribution — none of that should ever be ported, and the fork-invariants guard can pin the attribution surfaces so upstream merges or future ports can't silently drop them.

### 1b. Copyright in the Pro code itself

DocuSeal Pro/Enterprise features ship as a **separate proprietary codebase** that is not in this repository. AGPL freedoms fully cover writing *new* code that provides equivalent functionality; copyright does not protect functionality, only expression. The exposure is **provenance**: code copied or closely derived from DocuSeal's proprietary Pro source would infringe. Assessment of the surveyed sources:

- **Independently written from public docs/UI** (stated or evident): s256 (explicit disclaimer: never had Pro access, designed from public API docs), acul021 (OIDC from scratch), maximus-output, developbob, CareerPlug, vshaveyko, wabolabs. Copyright risk: low, assuming the statements are accurate.
- **Ported from another fork of unclear provenance:** Deenyoro credits its SSO/logo/reminders code to `docuseal-plus`; anything with a chain of custody through third-party forks inherits whatever taint exists upstream in the chain. Risk: still likely low (docuseal-plus also self-describes as independently written), but the chain is one link longer.
- The **"unlock" mechanic** (flipping upstream's own `data-with-*` builder flags, granting upstream's own CanCan ability symbols, emptying upstream's own placeholder partials): this modifies AGPL-licensed code in this repo, which the AGPL expressly permits. Not a copyright problem. It is a *relationship/positioning* consideration only (see 1c).

### 1c. Positioning and non-legal exposure

- Upstream sells these features. A public fork of a commercial OSS project that advertises "Pro features free" invites hostility and possible retaliation (e.g., upstream relicensing future versions, refusing engagement). A **private/internal deployment** (DocuSeal's actual posture) carries essentially none of this exposure, but AGPL §13 requires offering source to network users — which this fork already does — so "private" here means low-profile, not source-closed.
- Third-party ToS apply independently of DocuSeal: DocuSign's API terms (template import), Stripe's terms (payments), IdP terms.

## 2. Per-feature recommendation

| Beads | Feature | Copyright/provenance | Attribution impact | Recommendation |
|---|---|---|---|---|
| docuseal-i9r | OIDC SSO (acul021) | Clean-written, new gems | None | **Go** — lowest-risk substantive Tier 4 item. Test against live IdP before relying on it. |
| docuseal-8ys | force_sso_auth enforcement | Enforces a setting upstream itself ships in OSS | None | **Go** (after an SSO impl lands). |
| docuseal-4g4 | Automated reminders | OSS ships the settings UI; job is new code (docuseal-plus/s256 chain) | None | **Go** — prefer re-deriving the job fresh from this repo's idioms (flood-guard design as spec, not code) to cut the provenance chain. |
| docuseal-ve0 | DocuSign import (iancenry) | Not a DocuSeal Pro feature at all; DocuSign ToS governs API use | None | **Go** if the migration need exists. |
| docuseal-6dd | SAML SSO (Deenyoro) | Ported via docuseal-plus chain | None | **Conditional** — prefer acul021's OIDC; if SAML is needed, re-derive against ruby-saml >= 1.18.0 rather than porting the overlay. |
| docuseal-z86 | SMS invitations (wabolabs) | Clean-written, specs included | None | **Conditional go** — port `lib/sms.rb` + provider classes; rewrite the settings form against this repo's views. |
| docuseal-dh4 | Stripe payments | Clean-written but untested money paths | None | **Hold** until a real need exists; then port with full spec coverage first. |
| docuseal-4ty | Bulk send | Small, untested | None | **Go when needed** — low risk, low urgency. |
| docuseal-3ry | White-label + attribution-when-personalized | This fork is *already* white-labeled with attribution retained | Positive — developbob's pattern *adds* attribution | **Go for the attribution-when-personalized pattern**; the Intebec engine is unnecessary here (excise-list liability, private client repo). |
| docuseal-350 | Template-creation / one-off submission APIs | Clean-written (iancenry), no tests, Node dep | None | **Hold** — port only against a concrete API consumer; add tests during port. |
| docuseal-t0t | Teams/departments RBAC | Multiple sources, all invasive, weak tests | The `_role_select` un-gate removes an upsell (not attribution) | **Hold** — biggest merge burden for a single-operator deployment; revisit if DocuSeal gains multi-user teams. |
| docuseal-mqq | Embedded builder/form (vshaveyko) | Clean-written w/ specs; but the static-asset shadowing of upstream's Pro stub is deliberately adversarial mechanics | None (attribution untouched) | **Conditional** — if embedding is needed for DocuSeal, prefer implementing a clean `EmbedScriptsController` replacement over the shadowing trick, which survives on a technicality. |

## 3. Standing rules for any Tier 4 port (proposed)

1. **Never remove or weaken DocuSeal attribution** in interactive UIs, emails, or the landing source link. Encode the attribution surfaces in `config/fork_invariants.yml` (`must_contain` markers) so CI enforces §7(b) permanently.
2. **Prefer re-derivation over porting** when the source fork's provenance chain includes another fork, or when the source ships no tests. The surveyed catalogs serve as design documents.
3. **No Pro source contact.** Nobody working on this fork should read DocuSeal's proprietary Pro code or decompiled cloud assets; document that fact per feature in the implementing commit message.
4. **Third-party ToS check** per integration (DocuSign, Stripe, SMS providers, IdPs) at implementation time.
5. Keep the deployment posture: self-hosted, AGPL §13 source offer intact, no public marketing of "DocuSeal Pro features free."

## 4. Decision requested

Mark each row's recommendation as accepted/modified in this file (or in the beads issues), then unblock the corresponding `docuseal-*` issues. The blocked issues remain inert until then.
