# 01 — Approved scope and decision precedence

## Preserve exactly

| Area | Status carried forward | Technical consequence |
|---|---|---|
| REQVIORA V1 | Owner approved: functioning planning/design/Second Brain web platform, simulated customer UI only | Never emit deployable customer backend, real payments or live customer transactions |
| PB-V1 | Owner approved: six primary screens PB-01..PB-06; PDF/DOCX/TXT, Tamil/English voice, text, manual; human review | Source store, transcription correction, candidate claims, Owner-controlled confirmation, Builder prefill |
| 8-stage Builder | Owner-approved 166 feature entries, 47 listed buttons | Keep eight stable numbered stages, unchanged names and coverage; do not infer 166 DB tables |
| Step 01 | Prefilled & Editable approved | One canonical project information record; Create Project + Builder Step 1 use same authoritative values |
| Step 08 | Review & Export approved | Validation, review, final preview, approval and export capabilities are included; may be multiple detailed pages but not ninth Builder stage |
| AC-01A | Six project roles approved | Owner, Requirements Editor, Designer, Reviewer, Approver, Viewer |
| AC-01B | Multi-role approved | Union only of valid grants; overriding denies and server checks |
| AC-01C | Separate Reviewer/Approver approved | Reviewer cannot approve merely by being Reviewer |
| AC-01D | Strict Owner Control C1 approved | Editor proposes AI/critical requirement changes; only Owner confirms authoritative requirement/identity/scope changes |
| AC-01E | Controlled collaboration approved | Both Editor/Designer may map screens, Designer owns navigation/interactions, Editor proposes corrections; Designer may run analysis but not confirm |
| Super Admin | Explicit owner approval | One human platform tier, operational metadata only, no implicit private content/export, NEVER project approval |
| AC-01F–H, AC-02–09 | Owner-delegated design baseline | Viewer metadata default + fixed group/resource grants; atomic project Owner creation; default deny; independent Approver, no material self-approval; revocable read-only MCP |
| G0-07 | Previously deferred technical boundary | PB-V1 UX approval does not automatically approve AI/STT service/vendor limits |
| 137 UI mocks | First-pass screen mapping completed | Build route/FR trace audit; do not promise 137 unique deployed pages |

## G1 authoring choices (candidate interface conventions; need implementation review)

- API base `/api/v1`, HTTPS, provider-neutral bearer access token as an illustrative transport.
- Canonical IDs as server-generated UUIDs, stored as `uniqueidentifier` in SQL Server example; IDs stay stable across drafts/revisions, never derived from list positions.
- Schema versions `1.0.0` for project draft, Blueprint, registry and manifest **candidate contracts**. Changing them requires explicit version/migration policy.
- Draft conflict contract `ETag` + `If-Match`, `409 STALE_DRAFT_VERSION`; async commands use `Idempotency-Key`.
- Typed, allowlisted preview action kinds. No executable scripts/HTTP/SQL from AI output.
- Sample registry lists component types matching existing approved Components Studio direction plus Step 05 expanded families; implementation support must be tested, not assumed.
- Source-to-requirement-to-feature-to-screen-to-action-to-acceptance trace is a first-class graph.

## Still pending / blockers for actual code release

1. Choose identity provider/session token semantics, key management, MFA mechanism, verified account bootstrap; sign authorization hooks.
2. Exact SQL Server/hosting/region, file storage, secrets vault, backup frequency, retention/deletion rules, recovery objectives.
3. G0-07 AI/STT providers, Tamil/English quality benchmark, upload limits, consent text, quota/credit model and failure thresholds.
4. Versioned typed DTO schemas for all dynamic feature/screen/route/interaction create/update payloads (OpenAPI currently uses `ObjectWrite.payload` for these).
5. Final registry type/props matrix, renderer parity and cross-platform responsive limits per existing Step 05 scope.
6. Objective test thresholds for blocker/advisory rules, accessibility, performance, browsers, pilot acceptance.
7. Reversible seven-to-eight Builder migration with proof old approved revisions remain unchanged.
8. 137 individual mock screen interaction/pixel/FR review (the included registry is first-pass only).

None of these gaps should be disguised as owner approval or a working deployment.
