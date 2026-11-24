# 03 — REST API, errors, security and changes

## Contract files

- `api/reqviora.openapi.yaml` is OpenAPI 3.1 and currently declares **88 candidate HTTP operations**.
- `api/endpoint_inventory.csv` maps each operation to its responsible domain, RBAC action and remaining contract work.
- `api/coffee-shop.requests.http` provides illustrative calls against `api.example.invalid`; it is not a working server.

## Conventions

| Concern | Proposed rule |
|---|---|
| HTTP | HTTPS, `/api/v1`, JSON request/response except multipart file uploads and ZIP downloads |
| Identity | Authenticated subject, account active/verified, current project membership and action allow on **every** read/write, including jobs and indirect exports |
| RBAC | `x-rbac-action` references previously delegated 39 actions; field-level denial and Owner-only confirmation take precedence over broad endpoint grant |
| Concurrency | `GET /draft` returns strong `ETag`; draft mutation supplies `If-Match`; return **409** `STALE_DRAFT_VERSION` on stale writes |
| Idempotency | POST create/analysis/generation/validation/approval/export expects `Idempotency-Key`; retry must not repeat external AI costs or duplicate approved revisions |
| Status | 200 retrieval/updates, 201 created, 202 async, 204 revoke, 400 malformed, 401 unauthenticated, 403 forbidden, 404 inaccessible, 409 stale/conflict, 422 domain blocker, 429 quota/rate limit |
| Errors | `application/problem+json`: `code`, `status`, `title`, `detail`, `correlationId`, optional `affectedObjectIds`; no raw prompts or secrets |
| Source uploads | MIME sniff, allowlist, size cap pending, parser sandbox, private storage; text/manual/voice/transcripts remain separately attributed |
| Background jobs | `queued/running/partial/completed/failed/cancelled`, input revision/version, job ID, bounded retries, safe status display |
| Pagination | Cursor/list shape is illustrative; before scaling, define exact cursor signature, page size and ordering per endpoint |

## High-priority vertical slice request order

`POST /projects` → `GET /projects/{id}/draft` → `POST /sources/text` → `POST /analysis-jobs` (optional) → `GET /candidate-claims` → `POST /candidate-claims/{id}/decision` (Owner only) → `PUT /builder/steps/1` → `PUT /builder/steps/2` → `POST /blueprint/compile` → `POST /preview-sessions` → `POST /validation-runs` → `POST /approvals` (independent Approver) → `POST /exports` → `GET /exports/{id}/manifest`.

## Do NOT hide remaining contract gaps

- Generic `ObjectWrite.payload` is deliberately **not a finalized per-feature DTO**. Requirements, features, screens, routes, interactions and editor mutations require separately versioned full schemas before frontend/backend work on those endpoints runs in parallel. No blind permissive JSON acceptance.
- Builder Step payload in OpenAPI is also a placeholder container: per-Step strict schema, optional/required validation and role-based field permissions still need endpoint-specific definition.
- External authentication details, storage upload flow (direct multipart vs signed object upload), consent UX, provider quotas, and voice transcription service are unresolved deployment/technical decisions.
- OpenAPI server host `api.example.invalid` is a **placeholder**; not a reachable endpoint.
- `GET /exports/{id}/manifest` currently links the *approved* manifest v1 schema. Explicit draft manifest contract must be versioned before draft exports are implemented.
- JSON schema validates shapes; server must also enforce cross-reference integrity (requirement → feature → screen → action) and business rules.

## Important security negative cases

- Viewer may not read unpublished draft/source/ZIP without a grant even if they know the exact URL.
- A combined Editor+Designer cannot change Owner-only confirmed AI requirement or project's in/out scope.
- Reviewer alone cannot approve. Platform Super Admin cannot approve or download customer ZIP implicitly.
- Revoked MCP identity loses access on its next read. MCP is not simply an extra unrestricted REST user.
- Stale ETags, stale validation hashes, mixed-version exports, unsupported component types/props and unsafe preview actions must fail closed.
