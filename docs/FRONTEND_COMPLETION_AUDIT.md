# REQVIORA Frontend Completion Audit

Date: 2026-11-26\
Branch: `Varmitha`\
Scope: Flutter Web frontend only

## Remote branch snapshot

The final fetch on 2026-11-26 observed `origin/develop` at `bd8197b`, Thikal's branch at `5a12030`, and Shayiny's branch at `697b5bd`. This working tree integrates Thikal's earlier account-security commit (`f8681f6`) and Shayiny's editor sequence through `c43049b`. The contributor branches advanced while this pass was being verified. Their newer voice, graph, permissions, AI-job, recovery, ZIP, and Backend Blueprint implementations were inspected by commit/file summary but were not bulk-copied into this already-dirty tree without conflict-level review and regression testing. They are reusable candidates, not completed functionality on `Varmitha`.

## Contract boundary

The running frontend currently calls implemented ASP.NET routes under `/api/...`. The checked-in G1 OpenAPI package describes broader routes under `/api/v1/...`, but `contracts/g1/api/endpoint_inventory.csv` marks every one of those routes `candidate-v1` and instructs implementers to verify source, authentication, schema, and negative tests before implementation. `contracts/g1/docs/03_api_contract_guide.md` also records unresolved authentication, upload, consent, provider-quota, and voice-transcription decisions.

Therefore this pass does not silently switch existing repositories to `/api/v1`, invent response DTOs, or display successful operations for candidate endpoints. Candidate routes are listed below as backend dependencies.

## Existing frontend reused and integrated

- Existing project creation, source text/file input, local requirement review, eight-step Builder, Blueprint editing, preview, validation, approval, and official ZIP download flows.
- Thikal account-security work from `origin/feature/thikal-v4-frontend-development`: OTP login field, in-memory access/refresh sessions, generation-bound single-flight token refresh, password recovery/reset, email verification, authenticator MFA provisioning/verification, secure logout, protected routes, and account-isolated Riverpod caches.
- Shayiny work from the twelve commits after the merge-base on `origin/feature/shayiny-v4-components-editor`: nested draft compatibility, theme mode/layout tokens, screen access roles, screen editor verification, editable local Blueprint preview, autosave, metadata preservation, accessibility, and post-approval validation lock.
- Existing uncommitted Varmitha administration console: MFA-per-read access, allowlisted operational metadata, section navigation, search, pagination, session invalidation, empty/loading/error states, and safe handling of 401/403/404/429 responses.

## User work packages

| Package | State after this pass | Evidence and remaining dependency |
| --- | --- | --- |
| FU01 Authentication and account security | Partially complete and integrated | Recovery/reset, email verification, OTP login, refresh/retry, memory-only tokens, protected routes, logout, and authenticator setup are implemented and tested. Profile, change email/password, active sessions, login history, recovery-code use, and a backend-driven session-expiry policy have no verified frontend contract. Reused `/api/auth/*`, `/api/account-security/*`, and `/api/security/mfa/*` branch integration requires matching backend availability. |
| FU02 Voice recording and transcription | Frontend-local subset remaining; backend/design blocks transcription | Current Input Studio supports text and PDF/DOCX/TXT uploads. Browser recording controls, an in-memory audio preview, and client-side language selection are independently achievable but are not implemented in this pass. Consent persistence, audio upload, job polling, and transcript correction require confirmed contracts. Candidate dependencies: `POST /api/v1/projects/{projectId}/transcription-jobs` and `PATCH .../transcripts/{transcriptId}`; the contract guide says voice provider and consent decisions remain unresolved. |
| FU03 AI requirement extraction | Backend blocked | Existing local candidate review is preserved. Real analysis start/polling, evidence/confidence DTOs, and clarification APIs are candidate-only: analysis jobs, candidate claims, decisions, and clarifications under `/api/v1`. |
| FU04 Project sharing and permissions | Backend blocked | No verified membership/invitation backend is consumed. Candidate dependencies cover members, invitations, acceptance, roles, removal, ownership transfer, and viewer grants. |
| FU05 Graphical navigation editor | Partially complete; local canvas remaining | Screen/navigation editing, interaction validation, role data, and persistence are present. A local draggable/pannable/zoomable node canvas and conditional-edge layout are independently achievable but are not implemented in this pass. Server persistence remains blocked because `PUT /api/v1/projects/{projectId}/route-layout` is candidate-only. |
| FU06 Component and visual editor | Substantially complete | Component registry, feature/screen mapping, screen roles, property inspection, responsive editing, mouse reordering, undo/redo, autosave, Blueprint persistence/recovery, theme tokens/modes, nested components, safe preview, and accessibility tests are integrated. Dynamic component registry/design-token `/api/v1` routes remain candidate-only. |
| FU07 Real AI UI generation | Backend blocked | Template/local Blueprint generation and editable preview remain available. Real generation jobs, alternatives, regeneration, and provider failure states require candidate generation/design endpoints and confirmed DTOs. |
| FU08 Approval, revision and export | Partially complete | Validation, approval confirmation, immutable revision ID handling, approved ZIP download, and ZIP signature checks are present. Revision list/detail/history, historical preview, draft restoration, export history, and manifest integrity UI require verified revisions/exports contracts. |
| FU09 Second Brain documentation viewer | Frontend-local subset remaining; canonical data backend blocked | No documentation viewer is wired. A safe local JSON/Markdown viewer with in-document search is independently achievable but is not implemented in this pass. Canonical Second Brain, traceability, validation, revision, manifest, and download data still require verified DTOs and an implemented API base. |
| FU10 MCP developer handoff | Backend blocked | No grant UI is wired because create/list/revoke, connection configuration, scope vocabulary, access history, and credential-delivery semantics are not verified. Candidate grant routes exist; the governance document states REST grant management is not MCP transport and credentials must not be stored in browser storage. |

## Admin work packages

The integrated console is deliberately metadata-only. It never renders transcripts, requirements, Blueprint JSON, private documents, or export archives.

| Package | State after this pass | Evidence and remaining dependency |
| --- | --- | --- |
| FA01 Admin login and MFA | Partially complete | Shared OTP login, authenticator setup, protected `/admin`, per-read six-digit MFA, and secure logout exist. Recovery-code login and admin-specific recovery/session policies require verified backend contracts. |
| FA02 Admin dashboard | Read-only foundation complete | Overview, system report, and health sections render allowlisted operational values with responsive navigation and real error states. |
| FA03 User management | Read-only partial | User directory/search/pagination and role/MFA/verification metadata are available. Suspension, reactivation, and session revocation are not wired; only candidate `/api/v1/admin/users*` actions are documented. |
| FA04 Roles and permissions | Read-only partial | Role directory metadata is available. Permission matrix and authorized mutations have no verified implemented contract. |
| FA05 Project oversight | Read-only partial | Metadata-only project directory/search/pagination is available and excludes private project content. Filter/status schemas require backend confirmation. |
| FA06 MCP grant management | Backend blocked | Candidate list/emergency revoke routes exist, but revocation reason/audit schemas and the actual backend base/version are unverified. |
| FA07 Export diagnostics | Backend blocked | No verified export-diagnostics admin endpoint or DTO is present in the checked-in contracts. |
| FA08 Validation monitoring | Backend blocked | No verified aggregate validation-monitoring endpoint or DTO is present. |
| FA09 Security and audit logs | Read-only partial | Audit events, HTTP status filter, and login-security summary are available through the existing metadata API. MFA/account/session event taxonomy and pagination contracts require backend confirmation. |
| FA10 System health and AI queue | Read-only partial | Dependency health and system report reads are present. Queue jobs, retries, workers, and safe failure DTOs require a verified endpoint; only candidate `GET /api/v1/admin/job-health` is documented. |
| FA11 Platform settings | Backend blocked | No approved settings, feature-flag, retention, version-history, or rollback endpoint is documented. |
| FA12 Support and incident management | Backend blocked | No approved support-ticket or incident endpoint is documented. |
| FA13 Admin profile | Partially shared with FU01 | Password recovery/reset, email verification, authenticator setup, and logout are shared. Profile edit, password/email change while signed in, active sessions, revocation, and login history lack verified contracts. |

## Security and privacy checks

- Access and refresh tokens are kept only in `AuthSession` memory and are cleared together.
- Requests and private Riverpod caches are bound to a monotonically increasing session generation, so an old-account request cannot be replayed or rendered after an account change.
- Concurrent and staggered 401 responses reuse the same token rotation. A rejected refresh clears the session; a transient refresh network error does not discard a potentially valid session.
- Admin responses are shape-validated before rendering and each section uses an explicit field allowlist.
- Admin UI does not expose raw exception details for authentication/authorization/backend-unavailable states.
- Official ZIP bytes are saved only after ZIP signature validation.
- Local/demo mode cannot open the administration route.

## Backend dependencies requiring confirmation

1. Decide whether production uses the current `/api/...` controllers, the candidate `/api/v1/...` surface, or a versioned compatibility layer.
2. Promote required `candidate-v1` endpoints to an implemented/approved state with exact request/response/error schemas and negative authorization tests.
3. Confirm browser voice capture format, upload flow, consent record, Tamil/English transcription provider, quotas, retention, and retry semantics.
4. Confirm background job polling intervals, terminal statuses, idempotency behavior, and safe failure payloads for analysis and generation.
5. Confirm account profile/change-email/change-password/session/recovery-code endpoints.
6. Confirm admin mutation, export diagnostics, validation aggregates, platform settings, support/incident, queue, and audit schemas.
7. Confirm MCP grant secret delivery: a raw credential may be shown once in transient UI but must never be written to browser storage or logs.

## Remaining frontend work after backend confirmation

First review and selectively integrate the post-snapshot contributor commits, starting with Shayiny's recovery/ZIP/Backend Blueprint bridge and then Thikal's local voice/graph work; do not assume their candidate API contracts match production. Complete the independently achievable browser-audio preview, graphical route canvas, and safe local documentation viewer. Create contract tests for each promoted endpoint, then implement the server-backed screens in this order: voice/AI ingestion, sharing/permissions, real generation, revision/Second Brain, MCP handoff, and finally admin mutation/monitoring/settings/support pages. Tamil localization is wired and covers the new account/admin access surfaces, but a full translation pass over existing English-only Builder content remains. Add English/Tamil strings for every new screen and run the complete analyzer/test/web-build gate after every independently reviewable package.
