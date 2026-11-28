# REQVIORA Frontend E2E Test Matrix

Updated: 2026-11-28 (Asia/Colombo)

## Live environment evidence

- Expected frontend: `http://localhost:3000`
- Expected backend: `http://127.0.0.1:5264`
- Production-mode API define: `REQVIORA_API_BASE_URL=http://127.0.0.1:5264`
- Production-mode demo define: `REQVIORA_LOCAL_DEMO=false`
- Backend Swagger was reachable with HTTP 200. Unauthenticated `GET /api/projects` and `GET /api/admin/validation/summary` correctly returned HTTP 401.
- No frontend listener was available on port 3000.
- No authorized user/admin accounts, mailbox access, MFA factor, provider credentials, PayHere sandbox authorization or isolated shared test dataset were supplied.

No email verification, MFA, authorization boundary, provider response or payment result was bypassed. No live mutation or billable operation was attempted.

## Scenarios

| ID | Scenario | Status | Evidence / blocker |
|---|---|---|---|
| E2E01 | Registration, email verification and login | BLOCKED | Requires reachable frontend plus authorized mailbox/SMTP-backed test identity. |
| E2E02 | Personalized dashboard and identity | BLOCKED | Requires a verified authenticated user session. Automated profile/greeting tests pass independently. |
| E2E03 | Project creation and persistence | BLOCKED | Requires an authorized isolated user and database mutation approval. Repository/widget tests cover create/list/edit contracts. |
| E2E04 | Sharing and role enforcement | BLOCKED | Requires at least two authorized isolated accounts. Role enforcement remains covered by automated tests. |
| E2E05 | PDF/DOCX parsing | BLOCKED | Requires an authorized project and configured document-intelligence service. |
| E2E06 | Voice transcription | BLOCKED | Requires browser microphone permission and configured transcription provider. |
| E2E07 | AI extraction and review | BLOCKED | Requires authorized provider-backed, potentially billable AI execution. |
| E2E08 | Builder and draft restoration | BLOCKED | Requires authenticated live project state. Automated builder/draft concurrency coverage remains the acceptance evidence. |
| E2E09 | Validation, approval and immutability | BLOCKED | Requires authenticated live project/revision records. |
| E2E10 | Official export and archive integrity | BLOCKED | Requires approved live revision and export worker/storage. |
| E2E11 | MCP grant, transport and revocation | BLOCKED | Requires an approved revision, live MCP transport and isolated grant authorization. |
| E2E12 | PayHere sandbox and entitlement | BLOCKED | Requires explicit sandbox credentials and authorization; no payment was initiated. |
| E2E13 | Administrator login and MFA | BLOCKED | Requires an authorized administrator identity and MFA factor. |
| E2E14 | Backend-supported admin modules | BLOCKED | Requires an authorized administrator session and isolated records. Automated repository/widget tests cover supported contracts. |
| E2E15 | Browser refresh and session recovery | BLOCKED | Backend reference lacks the secure cookie refresh/bootstrap contract required for process-loss recovery. |
| E2E16 | Logout, account isolation and unauthorized rejection | BLOCKED | Requires at least two authorized live accounts. Automated session/isolation and route-security tests remain in force. |

## Interpretation

`BLOCKED` means the scenario was not executed live and no success is claimed. It does not mean the corresponding frontend source is absent. Automated verification and live integration are separate gates.
