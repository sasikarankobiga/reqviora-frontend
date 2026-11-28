# REQVIORA Frontend Full Test Report

Date: 2026-11-28 (Asia/Colombo)

## Executive result

The latest verified Batch 07 baseline (`0c816bb0c6cc3ccdda6f97b43218ff151868b563`) and all earlier contributor work are preserved. Batch 08 added authenticated personalization, Unicode-aware identity, local-time greetings, independent backend-connection state, validated route restoration, and draft concurrency recovery in commits `980f425`, `95b29ef`, and `85aa5f7`.

One additional route-restoration security defect was found during final audit: arbitrary local and public-auth destinations were accepted after login. Restoration is now restricted to known authenticated route families and rejects external URLs, unknown paths, auth/invitation paths, fragments, and backslash variants.

CI-equivalent local verification on Flutter 3.47.6 / Dart 3.13.5 passes: analyzer 0/0/0, 853/853 tests, G1 fixture validation, and a non-demo release web build. Live production readiness is not established because no isolated backend, database, SMTP, provider, MCP, PayHere sandbox, or authorized test accounts were available.

## Repository and environment

| Item | Evidence |
|---|---|
| Repository | `https://github.com/sasikarankobiga/reqviora-frontend.git` |
| Branch | `Varmitha` |
| Updated baseline | `0c816bb0c6cc3ccdda6f97b43218ff151868b563` |
| Batch 08 checkpoint | `85aa5f71d748574cddbbea4d6b9ab045b33d6a8e` |
| Backend reference | `54daf30be57fcb76aaa76c4b3fed45f8c6d44cef`, read-only |
| Develop reference | `447887ab03696974ebf008ce8ac9381f3a01eb65` |
| Actual divergence | `origin/Varmitha` 20 ahead / 0 behind `origin/develop` at audit time |
| Toolchain | Flutter 3.47.6 / Dart 3.13.5 |
| Disk | 22.79 GB free on C: during initial inventory |
| Live service check | Ports 3000 and 5264 not listening |

Multiple checkouts were inventoried. Older dirty worktrees were preserved. Work continued in the clean checkout already matching the authorized remote baseline.

## Automated verification

| Gate | Result |
|---|---|
| `flutter pub get` | PASS; lock resolved for CI-pinned SDK |
| `flutter gen-l10n` | PASS |
| Changed-file formatting | PASS |
| `flutter analyze --no-pub` | PASS: 0 errors, 0 warnings, 0 infos |
| Focused Batch 08/session/draft/admin gate | PASS: 65 tests |
| Responsive/localization/accessibility/security gate | PASS: 89 tests |
| Full Flutter suite | PASS: 853 passed, 0 failed, 0 skipped |
| Test-count change | +7 over the 846 Batch 07 baseline: identity, greeting, route restoration and draft concurrency coverage |
| G1 fixture validation | PASS: 4 schemas, 19 component types, 88 operations/75 paths, 39 RBAC actions, 137 screen rows, 4 negative cases |
| Release web build | PASS with HTTPS invalid test API and `REQVIORA_LOCAL_DEMO=false` |
| Conflict markers | PASS: none |
| `git diff --check` | PASS |
| Secret review | PASS after reviewing variable-name false positives; no literal credentials/keys found |
| Dedicated secret scanner | UNAVAILABLE: Gitleaks/TruffleHog/detect-secrets not installed |

G1 explicitly does not test SQL Server execution, real APIs, per-field RBAC, production ZIP integrity, AI providers, frontend rendering, or deployment.

## User modules

Each module is implemented for the current verified backend contract and passes applicable UNIT/WIDGET/MOCK_CONTRACT coverage. LIVE_API/BROWSER_E2E remains BLOCKED.

| ID | Automated/source status | Live limitation |
|---|---|---|
| FU01 Authentication | PASS | Backend/SMTP/test mailbox unavailable; refresh persistence awaits secure cookie contract |
| FU02 Account Security | PASS | Multiple live accounts/security events unavailable |
| FU03 Voice Processing | PASS | Browser microphone/transcription provider unavailable |
| FU04 AI Requirements | PASS | Billable provider requests not authorized |
| FU05 Project Sharing | PASS | SMTP and second authorized user unavailable |
| FU06 Document Intelligence | PASS | Storage/OCR/parser unavailable |
| FU07 Navigation Editor | PASS | Full browser assistive-technology audit not run |
| FU08 Blueprint/Builder | PASS | Live AI/backend workflow unavailable |
| FU09 Revision/Export | PASS | Live storage/export pipeline unavailable |
| FU10 Second Brain | PASS | Live approved package retrieval unavailable |
| FU11 MCP Handoff | PASS | MCP transport/client unavailable |
| FU12 Billing | PASS | PayHere sandbox and callback unavailable |

## Administrator modules

All fourteen areas have frontend implementations for currently supported contracts. Requested fields/actions missing from backend remain documented dependencies rather than simulated features.

| ID | Automated/source status | Limitation |
|---|---|---|
| FA01 Login/MFA | PASS | Live administrator/MFA unavailable |
| FA02 Dashboard | PASS | Live metrics unavailable |
| FA03 Users | PASS | Live mutations unavailable |
| FA04 Roles/permissions | PASS | Backend remains authority |
| FA05 Project oversight | PASS | Live private-data boundary unavailable |
| FA06 MCP grants | PASS | Supported filters/actions only |
| FA07 Export diagnostics | PASS | Supported filters only |
| FA08 Validation monitoring | PASS | Aggregate APIs only; no project/rule drill-down |
| FA09 Audit/security | PASS | Live event source unavailable |
| FA10 AI queue | PASS | Read-only; backend has no retry/cancel endpoints |
| FA11 Settings | PASS | Allowlisted setting only |
| FA12 Incidents | PASS | No ticket/conversation/internal-note/priority-update API |
| FA13 Profile/sessions | PASS for supported DTO/actions | Several descriptive fields/session pagination absent |
| FA14 Billing | PASS for sandbox monitoring/review | No entitlement API or real refund execution contract |

## Responsive, localization and accessibility

Automated coverage exercises 320x640, 375x812, 390x844, 768x1024, 1024x768, 1440x900 and other established sizes. Dedicated suites verify mobile/tablet layouts, keyboard activation, accessibility semantics, enlarged text, contrast, Tamil locale selection, Tamil controls, Unicode display names, and responsive billing/admin surfaces. No Flutter overflow/test exception was observed. A complete manual screen-reader and every-screen physical-browser audit remains NOT RUN.

## Security and privacy

- Tokens remain memory-only and session-generation scoped.
- Concurrent 401s share one rotation; stale-account responses fail closed.
- Network failure remains distinct from authentication expiry.
- Route restoration uses a strict local authenticated-route allowlist.
- Draft rebasing occurs only when the edited section still matches its baseline; same-section conflicts never overwrite newer server data.
- Admin MFA and server authorization remain authoritative.
- MCP credentials are one-time transient data and absent from list DTOs/storage.
- Payment redirects do not establish success or entitlement.
- No production mock fallback, hardcoded user identity, merchant secret, provider key, or fake success path was found.

## Architecture and dependencies

The existing feature boundaries and shared client/provider architecture remain intact. Pre-existing files over the documented 300-line target remain a maintainability concern; `authoring_page.dart` is approximately 3,841 lines. Broad decomposition is deferred to avoid destabilizing verified submission behavior. Backend gaps and recommendations are listed in `docs/REQVIORA_BACKEND_DEPENDENCIES.md`.

## Live verification and readiness

All twelve E2E workflows are BLOCKED because both declared services were offline and required isolated credentials/providers were absent. No shared database record, real payment/refund, billable AI call, MCP grant, administrator mutation, or unrelated session was touched.

- Automated/local release gate: PASS.
- Source implementation against current contracts: PASS with documented backend limitations.
- Live integration: BLOCKED.
- Production readiness: BLOCKED pending the isolated live matrix and backend session/refund/entitlement dependencies.
