# REQVIORA Final Frontend Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconcile the latest `Varmitha` branch, finish every frontend capability supported by the checked-in backend contracts, verify the complete product, and publish evidence-backed readiness documentation without fabricating live or provider results.

**Architecture:** Preserve the existing domain/data/application/presentation feature boundaries and the shared `ApiClient`, Riverpod session generation, and GoRouter guards. Treat the ASP.NET controllers at backend commit `54daf30be57fcb76aaa76c4b3fed45f8c6d44cef` as authoritative; unsupported features remain explicit dependencies. Work proceeds as small verified checkpoints, with current user-owned UX/session/draft changes reviewed before any new edits.

**Tech Stack:** Flutter Web, Dart, Riverpod, GoRouter, `package:http`, ASP.NET backend contracts, Flutter localization, GitHub Actions.

**Spec:** `C:/Users/UT011612/.codex/attachments/2b960fb8-31d7-4af3-85c9-c9eec0acb043/Pasted text.txt`

## Global Constraints

- Work and push only on `Varmitha` using `Varmitha Yogananthan <yvarmitha@gmail.com>` and authenticated account `VarmithaYogananthan`.
- Do not modify backend source, database schemas, `main`, or `develop`.
- Preserve concurrent remote work and user-owned working-tree changes; no force push or history rewrite.
- Use real backend contracts and real data only; test fixtures stay under `test/`.
- Keep tokens in memory, preserve server authorization/MFA, and never expose provider, merchant, storage, or signing secrets.
- Do not perform shared-data mutations, billable AI calls, MCP grants, payments, or refunds without isolated authorized data.
- Use CI-pinned Flutter 3.47.6 as the authoritative CI result; record local SDK differences separately.

## Review Focus

- A refresh/login redirect carrying a nested project route must restore only a validated local path and reject external/open redirects; covered by `test/route_restoration_security_test.dart`.
- Concurrent saves to different draft sections must rebase safely while same-section changes must never be overwritten; covered by `test/workspace_draft_api_test.dart` and project-draft tests.
- Account switches during profile, API, autosave, polling, or admin requests must reject stale responses; covered by auth/session isolation tests.
- Network failure must not masquerade as authentication expiry, and a rejected refresh must clear the correct account only; covered by API network/session tests.
- User-provided text, files, incident data, AI output, and MCP credentials must remain safely rendered/redacted and never persisted as runtime fallback data; covered by security and repository tests.

---

### Task 1: Reconcile and verify the latest shared baseline

**Files:**
- Review: current modified/untracked files reported by `git status`
- Update: `docs/REQVIORA_FINAL_COMPLETION_CHECKPOINT.md`

**Interfaces:**
- Consumes: `origin/Varmitha` and the preserved named stash backup.
- Produces: a stable baseline containing remote FA13/FA14 work plus reviewed local UX/session/draft changes.

- [ ] Fetch `origin`, fast-forward without rewriting history, and reapply preserved user changes.
- [ ] Review every changed file, conflict marker, dependency, and endpoint touched by the reapplied work.
- [ ] Run focused identity, route-restoration, session, draft, and admin profile/billing tests.
- [ ] Fix only reproducible failures and record evidence in the checkpoint document.
- [ ] Commit the reviewed critical UX/session/draft checkpoint.

### Task 2: Audit all user and administrator modules against source contracts

**Files:**
- Inspect: `lib/features/**`, `lib/app/reqviora_app.dart`, `test/**`
- Inspect read-only: backend controllers/contracts/services at commit `54daf30b...`
- Update: `docs/REQVIORA_FINAL_COMPLETION_CHECKPOINT.md`

**Interfaces:**
- Produces: an explicit COMPLETE/PARTIAL/IMPLEMENTATION_PENDING/BACKEND_DEPENDENCY/LIVE_VERIFICATION_PENDING/NOT_APPLICABLE checklist.

- [ ] Inventory all routes, repositories, providers, pages, tests, and backend endpoints.
- [ ] Confirm FU05/FU11/FU12 and FA06/FA07/FA08/FA10/FA11/FA12/FA13/FA14 against current contracts instead of duplicating them.
- [ ] Identify frontend-only gaps with an implemented backend contract and assign each to Task 3.
- [ ] Record every unsupported backend capability with authorization, impact, priority, and recommendation.

### Task 3: Close confirmed frontend-only gaps test-first

**Files:**
- Modify only the feature files identified by Task 2.
- Add focused tests beside the owning module under `test/`.

**Interfaces:**
- Consumes: authoritative endpoint/DTO signatures from Task 2.
- Produces: contract-correct UI/repository behavior without new endpoints or runtime mock fallbacks.

- [ ] For each reproducible gap, add a focused failing test naming the expected route, DTO, security boundary, and failure state.
- [ ] Run the focused test and record the expected failure.
- [ ] Implement the minimum typed repository/provider/UI correction.
- [ ] Run the focused test plus the owning module regression set.
- [ ] Commit each independently reviewable feature or security correction.

### Task 4: Verify critical UX, responsive behavior, localization, and security

**Files:**
- Test: identity/session/draft tests plus existing responsive, accessibility, localization, and security suites.
- Modify only when a test or source audit reproduces a defect.

**Interfaces:**
- Produces: evidence for personalized identity, time greetings, connection status, safe route restoration, draft recovery, representative widths, localization, and security handling.

- [ ] Verify Unicode initials and greeting boundaries/resume behavior.
- [ ] Verify authenticated connection states and secure logout/session-expiry behavior.
- [ ] Verify exact authorized route restoration and open-redirect rejection.
- [ ] Verify draft duplicate-save prevention, cross-section rebase, and same-section conflict preservation.
- [ ] Run responsive/accessibility/localization suites and scan hand-authored UI for unintended mojibake or secret leakage.

### Task 5: Produce final readiness, E2E, dependency, and run documentation

**Files:**
- Create: `docs/REQVIORA_FINAL_FRONTEND_READINESS.md`
- Create: `docs/REQVIORA_FRONTEND_E2E_TEST_MATRIX.md`
- Create: `docs/REQVIORA_BACKEND_DEPENDENCIES.md`
- Create: `docs/REQVIORA_FRONTEND_RUN_GUIDE.md`
- Update: `docs/REQVIORA_FINAL_COMPLETION_CHECKPOINT.md`

**Interfaces:**
- Produces: reproducible evidence and truthful blocked/not-run classifications with no secret values.

- [ ] Record current commits, SDKs, module inventory, tests, security checks, and known limitations.
- [ ] Record each E2E workflow as PASS/FAIL/BLOCKED/NOT RUN with the exact environment or authorization reason.
- [ ] Record backend dependencies with controller/endpoint/capability/authorization/impact/priority/recommendation.
- [ ] Document local and production build commands, required non-secret configuration names, routing, HTTPS, and CORS requirements.

### Task 6: Run the complete release gate and publish

**Files:**
- Review all intended changes and documentation only.

**Interfaces:**
- Produces: verified commits at equal local/remote SHAs and a completed GitHub CI run.

- [ ] Run `flutter pub get`, `flutter gen-l10n`, formatting verification, analyzer, focused suites, full tests, G1 validation, secret/dependency scans, and production web build.
- [ ] Confirm exact test/analyzer counts, build output, diff check, conflict scan, branch, identity, and GitHub account.
- [ ] Fetch and safely reconcile any new remote commits; rerun affected verification.
- [ ] Create reviewed documentation/test commits, perform push dry-run, then push only `Varmitha`.
- [ ] Verify local SHA equals `origin/Varmitha` and monitor CI to completion.
