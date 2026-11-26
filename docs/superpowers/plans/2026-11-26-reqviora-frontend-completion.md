# REQVIORA Frontend Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate all independently achievable User and Admin Flutter Web work on `Varmitha`, reuse contributor implementations, and report backend-dependent gaps without fabricating operations.

**Architecture:** Keep the existing clean feature layering and in-memory authentication boundary. Integrate the remote contributor branches selectively into the dirty worktree, then add focused repositories/pages only for approved contracts; every network-backed screen must expose loading, empty, error, permission, and unavailable-backend states.

**Tech Stack:** Flutter Web, Dart, Riverpod, GoRouter, `package:http`, Flutter localization, `flutter_test`.

**Spec:** User-supplied “REQVIORA — Complete Pending Frontend Development Only” brief and `contracts/g1/api/reqviora.openapi.yaml`.

## Global Constraints

- Work only in `C:\Users\UT011612\REQVIORA_Varmitha` on branch `Varmitha`; do not commit, push, rewrite history, or touch backend/database code.
- Preserve the existing uncommitted administration files and contributor attribution; use the remote branch implementations rather than rebuilding them.
- Tokens and credentials remain memory-only; clear all session material on logout or terminal refresh failure.
- Treat `contracts/g1/api/endpoint_inventory.csv` entries marked `candidate-v1` as dependencies until an implemented backend contract confirms them.
- Never display synthetic success for a backend operation that did not complete.
- Preserve REQVIORA branding, accessibility, responsive behavior, English/Tamil localization, and existing tests.

## Review Focus

- Concurrent 401 responses must share one token refresh and terminal refresh denial must clear the session.
- Malformed or partial API responses must fail safely rather than render private or invented data.
- Admin UI must render only explicitly allowlisted operational metadata and must not expose project content.
- Editor autosave, approval locks, nested Blueprint data, theme tokens, and screen roles must survive round trips.
- Routes that depend on unavailable APIs must show an honest dependency state and never claim completion.

---

### Task 1: Account security integration (FU01 / FA01 / FA13 foundation)

**Files:**
- Reuse/modify: `lib/core/auth/auth_session.dart`, `lib/core/network/api_client.dart`, `lib/features/auth/data/auth_repository.dart`
- Reuse/create: `lib/features/auth/presentation/account_security_pages.dart`
- Modify: `lib/features/auth/presentation/auth_page.dart`, `lib/app/reqviora_app.dart`, `lib/app/app_shell.dart`
- Reuse/create: `test/account_security_contract_test.dart`

**Interfaces:**
- Produces `AuthSession.startSession`, refresh-aware `ApiClient`, password/email/MFA repository calls, and protected routes.

- [x] Import Thikal’s existing test coverage and run it against `Varmitha`; verify it fails because the security API is absent.
- [x] Integrate the branch implementation while reconciling `/admin` routing and existing dirty shell changes.
- [x] Run account-security tests and the full suite; preserve memory-only credential handling.

### Task 2: Component/editor integration (FU05 / FU06 / FU08 safeguards)

**Files:**
- Reuse/modify the 21 production/test files changed by `origin/feature/shayiny-v4-components-editor` after `origin/develop`.

**Interfaces:**
- Produces nested draft preservation, theme tokens, screen access roles, autosave/recovery, approval locks, and safe preview behavior.

- [x] Import Shayiny’s post-merge tests first and run them; verify the missing behavior fails on current `Varmitha`.
- [x] Integrate production changes commit-by-commit in dependency order without rewriting unrelated work.
- [x] Run the imported tests and full suite.

### Task 3: Administration metadata console (FA02–FA10 available reads)

**Files:**
- Preserve/modify: `lib/features/administration/data/repositories/admin_repository.dart`
- Preserve/modify: `lib/features/administration/presentation/pages/admin_page.dart`
- Preserve/modify: `test/admin_repository_test.dart`
- Reconcile: `lib/app/reqviora_app.dart`, `lib/app/app_shell.dart`

**Interfaces:**
- Produces validated MFA-gated metadata reads with per-section field allowlists, search, pagination, empty/error states, and session-change invalidation.

- [x] Extend tests to catch sensitive-field leakage, malformed responses, invalid paging/status filters, and route/session access errors.
- [x] Run targeted tests and confirm each new assertion fails for the intended missing behavior.
- [x] Implement only the minimal safe repository/page behavior required by the tests.
- [x] Run targeted tests and full suite.

### Task 4: Contract-backed project operations audit (FU02–FU10 / FA03–FA13)

**Files:**
- Create: `docs/FRONTEND_COMPLETION_AUDIT.md`
- Modify only feature files whose endpoint and schemas are confirmed by repository documentation.

**Interfaces:**
- Produces a package-by-package evidence matrix: reused, implemented, frontend-ready/backend-blocked, or absent from approved contracts.

- [x] Compare each requested workflow with active routes, repositories, OpenAPI schemas, endpoint inventory state, and tests.
- [ ] Implement all remaining frontend-only workflows; session/editor safeguards were completed, while browser-audio preview, a local graph canvas, and a safe local documentation viewer remain.
- [x] Record exact backend endpoints/schema decisions blocking the remaining actions, including the `/api` versus `/api/v1` mismatch.

### Task 5: Verification and manual handoff

**Files:**
- Modify: `README.md` only if the verified pending/completed summary is stale.
- Update: this plan’s checkboxes and `docs/FRONTEND_COMPLETION_AUDIT.md`.

**Interfaces:**
- Produces actual analyzer/test/build evidence and exact manual add/commit/push commands.

- [x] Run `dart format` on changed Dart files.
- [x] Run `flutter pub get`, `flutter gen-l10n`, `flutter analyze --no-fatal-infos`, `flutter test`, and `flutter build web --release`.
- [x] Inspect `git diff`, `git status --short`, branch, remote, identity, and contributor branch differences.
- [x] Report changed files, reused work, API integrations, blockers, remaining work, and manual commit/push verification commands without committing or pushing.
