# 06 — Contract QA, repository boundaries and five workstreams

## Local QA vs real product QA

`python tests/validate_pack.py` performs offline syntax and sample tests (JSON Schema, cross refs, negative sample, OpenAPI parameter checks, 19 manifest names, RBAC count). This does **not** test a deployed API, SQL Server execution, real role checks, actual ZIP bytes, web accessibility or external AI performance.

Read `tests/test_catalog.md` for the remaining mandatory integration cases. Never claim release-ready based only on static validation.

## Recommended two-repository architecture (from previous owner direction)

**Frontend repo:** Flutter Web app, typed generated API client, UI state/repositories, PB-V1, 8-step Builder, component renderer/registry, mock preview, accessibility and visual tests. Backend secrets must never be included.

**Backend repo:** ASP.NET Core API candidate, domain/service layers, EF migrations, validation/AI orchestration adapters, private object storage, export worker, approval transactions, RBAC, audit and MCP service. Web app never talks directly to DB/AI secrets.

**Shared contracts:** Publish a versioned artifact from a separately controlled `contracts/` directory, CI package or pinned submodule; do not manually diverge copy/pasted DTOs. Contract repository choice is open; this ZIP is repo-ready content for both teams.

## Suggested five parallel workstreams (names intentionally unassigned)

| Stream | Initial deliverables | Dependencies |
|---|---|---|
| 1. Frontend PB + Builder | PB-V1 six families, eight Builder stage shell, API clients, save/409 UX | API ETags, RBAC, Step payload schemas |
| 2. Frontend renderer + editor | Component registry, safe Blueprint renderer, navigation/preview, design history | Blueprint schema, actions/route IDs, component props |
| 3. Backend identity + projects | Accounts, membership, Owner create, RBAC middleware+service policy, draft storage, audit | AC baseline, SQL schema |
| 4. Backend requirements + generation | Sources, candidates, trace graph, deterministic template compiler, provider-swappable AI gateway | source contracts, G0-07 deferred vendor decision |
| 5. QA + approvals/exports/ops | Validation rules, independent approvals, canonical ZIP/MCP, negative tests and CI gates | Stable draft/revision, Source/Blueprint IDs, access control |

These are **responsibility buckets**, not a new approved reassignment of the existing five people. Confirm named ownership in the GitHub issue plan before assigning work.

## Build order

1. G1 contract CI and test fixtures with versioned schema IDs.
2. Identity/project create + atomic Owner membership + draft GET/save/409.
3. PB source ingest (text/manual first), suggestions with Owner review and source provenance. Voice and remote AI adapters remain gated by technical review.
4. Builder 01/02 confirmed prefill, screen selection, trace graph, route validation.
5. Blueprint compile/template rendering, component registry and mock navigation.
6. Remaining Builder steps 03–08 with editor history and deterministic validation.
7. Independent approval transaction, 19+manifest export, permissioned read-only MCP.
8. End-to-end pilot, security/accessibility tests, observability and controlled rollout.

## Entry/exit criteria for G1 freeze

- Every P0 endpoint has request/response JSON schema with no unbounded `payload` placeholder and positive/negative examples.
- All stage payload schemas, 39 RBAC action mappings and creator/Owner/Approver cases covered.
- Blueprint renderer + component registry semantically compatible and tested; no executable actions.
- DB migration runs and rolls back in disposable SQL Server environment with proper FKs/constraint checks.
- Approved revision hash stable, zero cross-project leaks, ZIP manifest bytes and hashes valid.
- UI route mapping individually audited against 137 first-pass mockups and all 166 Builder feature entries.
- Technology, hosting/region, file retention, G0-07 AI/STT providers and measurable release thresholds resolved via separate approved technical review.

**Current status is SPECIFICATION DRAFT, not a completed G1 implementation, signed engineering architecture freeze, live release, or 137-screen functional audit.**
