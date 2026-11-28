# REQVIORA Frontend E2E Test Matrix

Date: 2026-11-28 (Asia/Colombo)

## Environment check

Expected frontend: `http://localhost:3000`

Expected backend: `http://127.0.0.1:5264`

Result: both ports were NOT LISTENING. No authorized user/admin credentials, isolated database, SMTP recipient, provider keys, MCP client, or PayHere sandbox/callback configuration was supplied.

Automated unit/widget/mock-contract results are recorded separately and are never substituted for live evidence.

| ID | Workflow | Status | Exact blocker / safe boundary |
|---|---|---|---|
| E2E-01 | Register, real email verification, login, personalized dashboard, refresh, logout | BLOCKED | Backend/SMTP/test mailbox unavailable; secure page-refresh restoration additionally requires a backend HttpOnly-cookie contract |
| E2E-02 | Project create, persist, refresh, logout/login | BLOCKED | Backend and isolated database unavailable |
| E2E-03 | Invite second user, delivery, acceptance, permission mutation | BLOCKED | Backend, SMTP, and second authorized account unavailable |
| E2E-04 | PDF/DOCX parsing and evidence extraction | BLOCKED | Backend storage/OCR/parser unavailable |
| E2E-05 | Browser microphone, upload, transcription, edit/save | BLOCKED | Browser runtime and transcription provider unavailable |
| E2E-06 | AI extraction, polling, results and clarifications | BLOCKED | No authorization for billable provider calls or isolated data |
| E2E-07 | Builder Steps 01-08, save, refresh, exact route restore, validate | BLOCKED | Backend and authorized account unavailable |
| E2E-08 | Generate, validate, approve immutable revision, export and integrity | BLOCKED | Backend/storage/export pipeline unavailable |
| E2E-09 | Create MCP grant, transport access, revoke and verify rejection | BLOCKED | MCP service/client and isolated approved revision unavailable |
| E2E-10 | PayHere sandbox checkout, signed callback, entitlement refresh | BLOCKED | Sandbox merchant setup and internet-reachable callback unavailable; no real payment attempted |
| E2E-11 | Admin login/MFA and all admin modules | BLOCKED | Authorized isolated administrator/MFA and backend unavailable |
| E2E-12 | Cross-account/project, revoked session/grant, expiry and cache isolation | BLOCKED | Multiple isolated accounts and services unavailable |

## Safe execution prerequisites

Use disposable test accounts and projects only. Provide an isolated backend/database, SMTP test inbox, non-production AI/OCR/storage configuration, MCP test client, and PayHere sandbox merchant/callback. Explicitly designate sessions/grants/refunds before destructive actions. Never use production secrets or shared-user records.
