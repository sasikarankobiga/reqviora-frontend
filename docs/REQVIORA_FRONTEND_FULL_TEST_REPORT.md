# REQVIORA Frontend Full Test Report

Date: 2026-11-27 (Asia/Colombo)

## Executive result

The verified repair branch was integrated into `Varmitha` by fast-forward and its contributor history was preserved. Nine verified workflow-intelligence API contract defects and one corrupted-text defect were repaired. Batch 01 then completed the user-facing invitation, MCP handoff, and billing transports against backend `54daf30be57fcb76aaa76c4b3fed45f8c6d44cef`. The complete local CI-equivalent suite passes on Flutter 3.47.6: analyzer 0/0/0, 791/791 automated tests, release web build, and G1 fixture checks.

This report does **not** establish production readiness. No authorized isolated backend, database, SMTP/MCP provider environment, or PayHere sandbox was supplied, so live API and browser E2E scenarios are blocked. FU05, FU11, and FU12 are implemented and pass mocked contract/widget tests; their live provider behavior remains unverified. Several administrator product areas remain unimplemented.

## Repository, integration, and environment

| Item | Evidence |
|---|---|
| Repository | `https://github.com/sasikarankobiga/reqviora-frontend.git` |
| Working branch | `Varmitha` |
| Initial remote `Varmitha` | `a600a14fe048be03d098680b67387228b1f69d6e` |
| Latest observed `develop` | `447887ab03696974ebf008ce8ac9381f3a01eb65` |
| Integrated repair | `2c1f61700f8bf86373e48f48872b85d7e39f8dcc` |
| Integration method | `git merge --ff-only origin/fix/frontend-348-issues` |
| Repair CI | PASS for repair SHA, GitHub Actions run 45969466775 |
| Backend reference | Read-only clone of `develop` at `54daf30be57fcb76aaa76c4b3fed45f8c6d44cef` |
| CI toolchain | Flutter 3.47.6, Dart 3.13.5 |
| Additional local toolchain | Flutter 3.50.1, Dart 3.14.0 |
| Host/browser | Windows; Chrome and Edge available |
| Disk | Approximately 29.5 GB free on C: and 165 GB on Z: at baseline |
| API configuration | Local default `http://127.0.0.1:5264`; release verification used invalid non-live URL and local demo disabled |

Git author and committer were configured locally as `Varmitha Yogananthan <yvarmitha@gmail.com>`. This is not treated as proof of the authenticated GitHub identity.

## Verification gates

| Gate | Result | Evidence |
|---|---|---|
| `flutter pub get` | PASS | Flutter 3.47.6 |
| `flutter gen-l10n` | PASS | Flutter 3.47.6 |
| `flutter analyze --no-pub` | PASS | 0 errors, 0 warnings, 0 info issues |
| `flutter test --reporter expanded` | PASS | 791 executed, 791 passed, 0 failed, 0 skipped |
| Chrome widget subset | PASS | 29 tests; overlaps the 745-test source suite and is not added to its denominator |
| `flutter build web --release` | PASS | Invalid API URL; `REQVIORA_LOCAL_DEMO=false` |
| G1 contract fixtures | PASS | 4 JSON Schemas, 19 candidate component types, 88 OpenAPI operations on 75 paths, 19 manifest references, 39 RBAC actions, 137 mock screen rows, and 4 negative cases |
| Conflict marker scan | PASS | No unresolved source markers |
| Secret pattern scan | PASS | Tracked files and intended diff; no dedicated secret-scanner executable was installed |
| `git diff --check` | PASS | No whitespace errors |

The historical analyzer baseline was 261 errors, 34 warnings, and 53 info issues. On Flutter 3.50.1 the repository produced 0 errors, 0 warnings, and 101 SDK-deprecation info notices introduced after the pinned toolchain. On the authoritative CI-pinned Flutter 3.47.6 toolchain the final result is 0/0/0.

## User module audit

Automated evidence below means UNIT, WIDGET, or MOCK_CONTRACT evidence. It is not live E2E evidence.

| ID | Classification | Automated evidence and limitation |
|---|---|---|
| FU01 Authentication | BLOCKED | Auth/session, refresh, recovery, verification, privacy, navigation, and localization tests pass; live SMTP/OTP/backend workflow blocked. |
| FU02 Account Security | BLOCKED | Profile, email/password, session, MFA, and privacy contract/widget coverage passes; live account isolation and security-event workflow blocked. |
| FU03 Voice Processing | BLOCKED | Repository/widget validation coverage exists; real microphone, upload, transcription provider, and cleanup E2E blocked. |
| FU04 AI Requirements | BLOCKED | Corrected candidate, clarification, generation, regeneration, polling, validation, 429/503 behavior, and malformed DTO coverage passes; live AI/provider workflow blocked. |
| FU05 Project Sharing | BLOCKED | Connected invitation/member lifecycle and permission tests pass; live SMTP delivery/recipient acceptance is unavailable. |
| FU06 Document Intelligence | BLOCKED | Upload and validation code/tests exist; live storage, OCR, parsing, retry, and privacy validation blocked. |
| FU07 Navigation Editor | BLOCKED | Graph/editor widget tests and multiple responsive sizes pass; complete keyboard/screen-reader/live-persistence browser audit not run. |
| FU08 Blueprint Generation | BLOCKED | Generation/regeneration DTOs, editing, undo/redo, autosave, concurrency, validation, and immutability-related tests pass; live generation and provider verification blocked. |
| FU09 Revision and Export | BLOCKED | Revision/export contracts, ZIP signature, corrupted ZIP rejection, and authorization tests pass; official live export pipeline blocked. |
| FU10 Second Brain | BLOCKED | Viewer and safe rendering coverage exists; approved live package retrieval/integrity E2E blocked. |
| FU11 MCP Handoff | BLOCKED | Connected approved-revision grant lifecycle, one-time credential cleanup and permission tests pass; actual MCP connectivity is unavailable. |
| FU12 Billing | BLOCKED | Server-authoritative pricing/checkout/status/history/entitlement and debug-only refund request tests pass; PayHere sandbox/callback verification is unavailable. |

User modules fully verified live: 0/12. All twelve are blocked by external/live verification; no user module remains unimplemented in this batch's verified contract scope.

## Administrator module audit

| ID | Classification | Automated evidence and limitation |
|---|---|---|
| FA01 Admin Login and MFA | BLOCKED | Login, enrollment, verification, recovery, route protection, invalid MFA, privacy, and widget tests pass; live identity/MFA workflow blocked. |
| FA02 Admin Dashboard | BLOCKED | Overview contracts, safe parsing/errors, loading, and responsive widget tests pass; live statistics/dependency health blocked. |
| FA03 User Management | BLOCKED | Search, pagination, disable/enable, role changes, authorization, confirmations, and session privacy tests pass; live admin API blocked. |
| FA04 Roles and Permissions | BLOCKED | Role repository allowlists and authorization contracts exist; complete live matrix and escalation verification blocked. |
| FA05 Project Oversight | BLOCKED | Project admin repository contracts exist; live private-content and authorization validation blocked. |
| FA06 MCP Grants | NOT_IMPLEMENTED | No connected admin grant directory/revocation product implementation. |
| FA07 Export Diagnostics | NOT_IMPLEMENTED | No complete admin export-diagnostics module. |
| FA08 Validation Monitoring | NOT_IMPLEMENTED | No complete admin validation-monitoring module. |
| FA09 Audit and Security | BLOCKED | Audit repository contracts and redaction allowlists exist; live audit source and access rejection blocked. |
| FA10 AI Queue Monitoring | NOT_IMPLEMENTED | User job flow exists, but no complete administrator queue-monitoring product. |
| FA11 Platform Settings | NOT_IMPLEMENTED | No settings/version/rollback administration product. |
| FA12 Support and Incidents | NOT_IMPLEMENTED | No incident administration product. |
| FA13 Admin Profile and Sessions | NOT_IMPLEMENTED | Generic account security exists, but the complete requested administrator profile/session module is absent. |
| FA14 Billing Administration | NOT_IMPLEMENTED | No billing administration implementation. |

Administrator modules fully verified live: 0/14. Six are blocked by external/live verification and eight are not implemented.

## API compatibility findings and repairs

The latest backend controllers and DTOs were inspected read-only. Nine mismatches/invalid assumptions were corrected in the workflow-intelligence path:

1. Replaced the legacy `/workflow-intelligence/*` candidate route with the authoritative project requirements candidate route.
2. Changed clarification listing to the requirement-scoped endpoint.
3. Corrected clarification creation path and request DTO.
4. Corrected clarification answer path and expected-revision DTO.
5. Removed use of the nonexistent `review-sync-status` endpoint and derived read-only synchronization state from real resources.
6. Removed the nonexistent duplicate candidate-staging operation; extraction already persists candidates.
7. Corrected Blueprint generation to `/blueprints/generate` with `requirementIds` and `expectedConcurrencyToken` only.
8. Corrected Blueprint regeneration to `/blueprints/regenerate` with expected token/revision and explicit editable feature/screen/component IDs.
9. Validated the authoritative `ProjectDraftResponse` shape instead of fabricated applied/reason/draftVersion/blueprint fields.

Regression tests cover the corrected success contracts, input validation, malformed responses, concurrency fields, 429 preservation, and 503 preservation. No backend files were modified.

## Responsive, accessibility, and localization findings

Existing widget coverage exercises 320×640, 360×640/800, 390×844, 768×1024, 1024×768, 1440×900, and 1920×1080 layouts. A 29-test Chrome subset passed for dashboard, Step 07 responsive/accessibility, and localization flows. Exact 375×812 coverage and a complete every-screen assistive-technology/browser pass were not available, so responsive/accessibility is classified BLOCKED rather than fully passed.

English/Tamil locale integration and workspace localization tests pass. Seven visible mojibake occurrences in prebuilder copy were repaired (`·` and `—`), and a source-encoding regression test now scans hand-authored Dart sources. A complete live review of every label and clipping state remains blocked.

## Security and privacy findings

Automated coverage passed for single-flight refresh, logout/session generation, cross-session response rejection, protected admin controls, malformed/unsafe responses, field allowlists, MFA privacy, ZIP validation, safe rendering, and one-time credential UI handling. No private keys or common token/credential patterns were found in tracked files or the intended change set. Live cross-account/cross-project enforcement, provider behavior, storage/document privacy, MCP transport, and payment entitlement cannot be certified without an isolated environment.

G1 verifies static contracts and fixtures only. It explicitly does not verify SQL Server, real APIs, per-field RBAC enforcement, production ZIP integrity, AI providers, frontend rendering, or deployment.

## Defects repaired and files changed

Ten confirmed frontend defects were repaired: nine API contract/behavior defects and one corrupted-text defect category. No independently reproducible defect remains in the locally executable gates; missing products and external verification gaps are tracked separately.

Production files:

- `lib/features/workspace/data/ai_intelligence_repository.dart`
- `lib/features/workspace/presentation/authoring_page.dart`
- `lib/features/prebuilder/presentation/ai_extraction_panel.dart`
- `lib/features/prebuilder/presentation/clarification_dialog.dart`
- `lib/features/prebuilder/presentation/prebuilder_pages.dart`

Regression tests:

- `test/ai_intelligence_repository_test.dart`
- `test/additional_api_contract_test.dart`
- `test/widget/clarification_dialog_test.dart`
- `test/source_encoding_regression_test.dart`

## Architecture, missing products, and remaining work

Pre-existing hand-authored Dart files still exceed the documented 300-line target. The largest is `authoring_page.dart` (approximately 3,796 lines); other notable files include `prebuilder_pages.dart`, `voice_input_panel.dart`, `auth_page.dart`, `simulated_preview.dart`, and `api_client.dart`. New Batch 01 files are at or below 300 lines, and the directly modified member dialog was reduced below 300 lines.

Major missing products are connected MCP administration, billing administration, admin export diagnostics, validation monitoring, platform settings, support/incidents, admin AI queue monitoring, and a complete admin-specific profile/session product.

Remaining blockers are: no authorized isolated backend/database; no SMTP, AI, OCR, storage, MCP, or PayHere sandbox configuration; and no complete live browser E2E environment.

## Release readiness

- Local release build readiness: **PASS**.
- Pull-request/publication readiness: **BLOCKED** pending authenticated-account verification and publication; no PR was requested or created.
- Production release readiness: **NOT ESTABLISHED** because live E2E/provider/security enforcement is blocked and required product modules are absent.
