# REQVIORA User Pending Modules Completion Report

Date: 2026-11-27 (Asia/Colombo)

## Scope and repository

| Item | Evidence |
|---|---|
| Repository | `https://github.com/sasikarankobiga/reqviora-frontend.git` |
| Branch | `Varmitha` |
| Base commit | `1fb538063667ee012e07be94412ea191b64a1955` |
| Backend reference | Read-only `develop` at `54daf30be57fcb76aaa76c4b3fed45f8c6d44cef` |
| Toolchain | Flutter 3.47.6, Dart 3.13.5 |
| Implemented scope | FU05 project invitations, FU11 MCP handoff, FU12 PayHere billing |
| Excluded scope | Administrator modules, backend, database/Supabase, real provider transactions |

## Status summary

| Module | IMPLEMENTATION_STATUS | AUTOMATED_TEST_STATUS | LIVE_VERIFICATION_STATUS |
|---|---|---|---|
| FU05 Project Sharing | COMPLETE against verified contracts | PASS | BLOCKED: no isolated backend/SMTP recipient environment |
| FU11 MCP Developer Handoff | COMPLETE against verified fixed-scope contract | PASS | BLOCKED: MCP service/client environment not supplied |
| FU12 PayHere Billing | COMPLETE for pricing, checkout, status, history, entitlement and development-only refund-request contract | PASS | BLOCKED: no authorized PayHere sandbox, callback, or credentials |

Implementation completion does not establish production readiness. No real email, MCP connection, payment, refund, database write, or provider callback was executed.

## FU05 implementation

- Added connected invitation list, create, resend, revoke, accept and reject transport.
- Added typed invitation/status/membership parsing with GUID, email, role, expiry, duplicate and cross-project validation.
- Added owner-only invitation management, editor/viewer restrictions, loading/empty/error/retry states, confirmation prompts and duplicate-submission protection.
- Added an authenticated deep-link response route. Pending tokens are retained only in memory, consumed once, and never logged or persisted.
- Removed the obsolete direct-member onboarding path. Member `PUT` is now used only for accepted-member role changes; new members must accept a verified email invitation.

## FU11 implementation

- Added approved-revision lookup plus create/list/revoke MCP grant transport.
- Enforced the backend lifetime range of 5 to 43,200 whole minutes and project/revision isolation.
- Represents the backend's fixed read-only MCP V1 capability accurately; no unsupported scope-selection DTO was invented.
- Added owner/payment/disabled-service error handling and active/expired/revoked metadata display.
- Raw credentials exist only in a one-time in-memory container, are redacted from string output, excluded from list models, and cleared on dismiss, dialog disposal, project/session change, or logout.

## FU12 implementation

- Added server-authoritative pricing, checkout, status, history and single-payment transport.
- Added integer minor-unit monetary models and strict status/currency/order validation.
- Checkout sends contact data only. The browser posts backend-signed fields only to `https://sandbox.payhere.lk/pay/checkout` or `https://www.payhere.lk/pay/checkout`.
- Redirect data is never accepted as payment proof. Backend payment status and `entitled` are authoritative; bounded polling stops after eight attempts, disposal, or session change.
- Added pending/success/failure/cancelled/refunded/disputed presentation, history, entitlement and duplicate-checkout prevention.
- The user refund-request route is development-only and returns `503` outside Development. The UI exposes it only in debug builds. Production refunds remain an administrator/provider workflow.

## Verified frontend-to-backend endpoint matrix

All routes require a Bearer access token except the provider notification route, which the frontend does not call.

| Method and route | Authorization | Request | Success response | Expected failures |
|---|---|---|---|---|
| `GET /api/projects/{projectId}/members` | Project reader | none | `200 ProjectMember[]` | `401`, `403`, `404` |
| `PUT /api/projects/{projectId}/members/{userId}` | Owner; existing accepted member only | `{role: Viewer\|Editor}` | `200 ProjectMember` | `400`, `401`, `403`, `404`, `409` if not a member |
| `DELETE /api/projects/{projectId}/members/{userId}` | Owner | none | `204` | `401`, `403`, `404`, `409` |
| `POST /api/projects/{projectId}/invitations` | Owner | `{recipientEmail, role}` | `201 ProjectInvitationDetails` | `400`, `401`, `403`, `404`, `409`, `429`, `503` after stored/email failure |
| `GET /api/projects/{projectId}/invitations` | Owner | none | `200 ProjectInvitationDetails[]` | `401`, `403`, `404`, `429` |
| `POST /api/projects/{projectId}/invitations/{id}/resend` | Owner | empty JSON | `200 ProjectInvitationDetails` | `401`, `403`, `404`, `409`, `429`, `503` |
| `POST /api/projects/{projectId}/invitations/{id}/revoke` | Owner | empty JSON | `200 ProjectInvitationDetails` | `401`, `403`, `404`, `409`, `429` |
| `POST /api/project-invitations/accept` | Verified recipient | `{token}` | `200 AcceptedProjectMembership` | `400`, `401`, `403`, `404`, `409`, `429` |
| `POST /api/project-invitations/reject` | Verified recipient | `{token}` | `200 ProjectInvitationDetails` | `400`, `401`, `403`, `404`, `409`, `429` |
| `GET /api/projects/{projectId}/approvals` | Project access | none | `200` approved revision metadata | `401`, `403`, `404` |
| `POST /api/projects/{projectId}/mcp/grants` | Owner; payment/feature gates | `{approvedRevisionId,lifetimeMinutes}` | `201 {grant,credential}` | `400`, `401`, `402`, `403`, `404`, `409` |
| `GET /api/projects/{projectId}/mcp/grants?page=1&pageSize=50` | Owner | none | `200 {page,pageSize,total,items}` | `401`, `402`, `403`, `404` |
| `POST /api/projects/{projectId}/mcp/grants/{grantId}/revoke` | Owner | `{reason}` | `200 grant metadata` | `400`, `401`, `402`, `403`, `404`, `409` |
| `GET /api/billing/pricing?projectId={projectId}` | Project reader | none | `200 {amountMinor,currency,displayAmount,gatewayEnabled,projectOverride}` | `401`, `403`, `404`, `503` |
| `POST /api/projects/{projectId}/billing/checkout` | Owner | contact fields only | `200/201 {paymentId,orderId,actionUrl,fields,expiresAt}` | `400`, `401`, `403`, `409`, `503` |
| `GET /api/projects/{projectId}/billing/status` | Project reader | none | `200 PaymentDetails` including authoritative `entitled` | `401`, `403`, `404` |
| `GET /api/projects/{projectId}/billing/history?page=1&pageSize=50` | Project reader | none | `200` paginated payments | `400`, `401`, `403`, `404` |
| `GET /api/billing/payments/{paymentId}` | Related reader/admin | none | `200 PaymentDetails` | `401`, `403`, `404` |
| `POST/GET /api/projects/{projectId}/billing/payments/{paymentId}/refund-request` | Owning payer and project owner; Development only | POST `{reason}` | `201 RefundRequestItem` / `200 RefundRequestItem` | `400`, `401`, `404`, `409`, `503` outside Development |

Invitation responses do not contain raw tokens. MCP list responses do not contain raw credentials. Billing responses do not contain card numbers, CVV, or merchant secrets.

## Files and tests

Production changes are grouped under:

- `lib/features/projects/{application,data,domain,presentation}` for invitations and member-access separation.
- `lib/features/mcp_integration/{data,domain,presentation}` for MCP grants.
- `lib/features/billing/{data,domain,presentation}` for billing and hosted checkout.
- `lib/app/reqviora_app.dart` and `project_overview_page.dart` for routing and entry points.
- `authoring_page.dart` only changes its member-access import after the dialog extraction.

Added/updated test suites:

- `test/project_invitations_repository_test.dart`
- `test/mcp_grant_repository_test.dart`
- `test/billing_repository_test.dart`
- `test/widget/project_members_dialog_test.dart`
- `test/widget/pending_user_modules_widget_test.dart`
- `test/widget/pending_user_modules_access_widget_test.dart`

The completed work adds 46 net tests over the verified 745-test baseline. Coverage includes DTO mapping, malformed/cross-project responses, permissions, invitation lifecycle, one-time token/credential behavior, duplicate checkout prevention, all payment states, session cleanup, and responsive rendering.

## Final automated evidence

| Gate | Result |
|---|---|
| `flutter pub get` | PASS |
| `flutter gen-l10n` | PASS |
| `flutter analyze` | PASS: 0 errors, 0 warnings, 0 info |
| `flutter test --reporter expanded` | PASS: 791 passed, 0 failed, 0 skipped |
| `flutter build web --release` | PASS with invalid API URL and local demo disabled |
| G1 contract fixtures | PASS: schemas, 88 OpenAPI operations/75 paths, RBAC and fixtures |
| `git diff --check` | PASS |
| Conflict-marker scan | PASS: 0 unresolved markers |
| Production-diff high-confidence secret pattern scan | PASS: 0 matches |
| Dedicated secret scanner | UNAVAILABLE: Gitleaks, TruffleHog and detect-secrets are not installed |

`flutter gen-l10n` passed. New user-visible module copy follows the repository's English/Tamil `uiText`/`LocalizedUiText` convention. Responsive widget coverage includes 320×640, 375×812, 390×844, 768×1024, 1024×768, 1440×900, and 1920×1080 without detected Flutter exceptions or overflow.

## Architecture and security findings

- New hand-authored Dart files are at or below 300 lines. The directly modified member dialog was reduced from 483 to below 300 lines.
- The existing `authoring_page.dart` remains approximately 3,796 lines and was touched only to redirect one import. Broad decomposition was outside this batch.
- No new architecture violation was introduced.
- No token, credential, merchant secret, connection string, or provider secret is persisted or logged by the new implementation.
- Frontend permission visibility is advisory; backend authorization remains authoritative.

## Remaining work and readiness

Remaining user-module source work in this batch: none against the verified backend contracts. Production refund requests remain unavailable because the only user route is deliberately Development-only; production refund execution is an administrator/provider concern.

Live blockers are an authorized isolated backend/database, SMTP and test recipient, enabled MCP service/client, and PayHere sandbox credentials with an internet-reachable signed-notification callback. Cross-account/cross-project enforcement, real delivery, actual MCP connectivity, payment notification/reconciliation, and refund behavior remain unverified.

Readiness assessment: source implementation and automated verification are complete; live integration and production readiness are **BLOCKED**.
