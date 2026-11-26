# REQVIORA Remaining Frontend Continuation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the verified `Varmitha` work, enforce a 300-line ceiling for hand-authored Dart files, and implement every independently achievable remaining frontend workflow without inventing backend behavior.

**Architecture:** Checkpoint the existing dirty work first, then reconcile contributor work in small feature slices. Add an architectural line-count test before refactoring, keep browser-only adapters behind conditional imports, and isolate UI sections into focused files with explicit repositories and state objects.

**Tech Stack:** Flutter Web, Dart, Riverpod, GoRouter, `package:http`, Flutter localization, browser media APIs, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-26-remaining-frontend-design.md`

## Global Constraints

- Work only on `Varmitha`; do not commit or push automatically.
- Preserve every current modified and untracked source file.
- Do not modify backend repositories, databases, or Supabase.
- Do not invent APIs or render synthetic backend success.
- Keep every hand-authored Dart file under `lib/` and `test/` at 300 physical lines or fewer; generated localization Dart is exempt.
- Write or import the behavioral test first, observe the intended failure, then implement.

## Review Focus

- Switching accounts while media, API, autosave, or recovery work is pending must not leak the previous account's data.
- Denied microphone permission and interrupted recording must release browser tracks and show a recoverable error.
- Graph nodes with missing screens, destinations, roles, or initial-screen references must remain visibly invalid and unsaved.
- Markdown/JSON/archive inputs must never execute HTML, scripts, paths, or archive entries.
- Candidate endpoints and malformed responses must produce explicit unavailable/error states rather than invented data.

---

### Task 1: Manual checkpoint and dependency-safe groups

**Files:** Existing 46 modified/untracked paths only.

**Interfaces:** Produces three reviewable commits: security/admin/localization, editor/project integration, and documentation.

- [ ] Verify the exact file list and cross-package imports for all three groups.
- [ ] Present exact `git add` and commit commands using the authorized identity.
- [ ] Wait for the developer to confirm the checkpoint commits before conflict-prone integration.
- [ ] Re-run `flutter test` after the checkpoint and record the new base commits.

### Task 2: Enforce the 300-line Dart architecture limit

**Files:**
- Create: `test/architecture/dart_file_length_test.dart`
- Split: every hand-authored Dart file currently over 300 lines into responsibility-based files.

**Interfaces:** Produces an architecture test that scans `lib/` and `test/`, excludes generated localization files, and reports every oversized path with its physical line count.

- [ ] Add the architecture test and run it to observe all current oversized files failing.
- [ ] Split application files by widgets, models, adapters, and presentation sections without changing public behavior.
- [ ] Split oversized test files by feature scenario while preserving every assertion.
- [ ] Run the architecture test until every hand-authored Dart file is at most 300 lines.
- [ ] Run the existing full suite to prove the refactor preserved behavior.

### Task 3: Browser voice recording

**Files:**
- Reuse selectively from Thikal: browser recorder/audio models, voice panel, `web/voice_recorder.js`, and focused tests.
- Modify: Input Studio integration and verified upload repository only.

**Interfaces:** Produces permission, start/stop/cancel, duration, preview/playback, language, consent, validation, cleanup, and verified upload states; transcription remains pending until a real server result exists.

- [ ] Import voice behavior tests first and observe missing-feature failures.
- [ ] Integrate browser media adapters behind conditional imports.
- [ ] Add consent and Tamil/English language state without storing sensitive audio metadata persistently.
- [ ] Connect only the verified upload/transcription contract and expose unavailable state otherwise.
- [ ] Run focused voice tests, the architecture test, and the full suite.

### Task 4: Graphical navigation editor

**Files:**
- Reuse selectively from Thikal: navigation graph model/editor and tests.
- Modify: Builder navigation step and verified draft persistence mapping.

**Interfaces:** Produces draggable nodes, edges, pan/zoom, conditional and role metadata, initial-screen selection, validation, responsive layout, and keyboard movement.

- [ ] Import graph tests first and observe missing-feature failures.
- [ ] Integrate the local canvas and invalid-reference diagnostics.
- [ ] Persist layout only through the verified draft contract; label candidate route-layout persistence unavailable.
- [ ] Add keyboard and responsive-canvas coverage.
- [ ] Run graph tests, the architecture test, and the full suite.

### Task 5: Safe local Second Brain viewer

**Files:**
- Create focused files under `lib/features/second_brain/` for models, safe renderers, navigation/search state, and presentation.
- Create focused tests under `test/second_brain/`.

**Interfaces:** Consumes only actual loaded project/draft/validation/revision data and produces categorized searchable Markdown/JSON previews without HTML execution or archive extraction.

- [ ] Write failing tests for categories, search, safe Markdown, safe JSON, and absence of fictional sections.
- [ ] Implement a pure documentation projection from available project data.
- [ ] Implement safe renderers and category navigation.
- [ ] Add the protected project route and explicit unavailable states for absent canonical data.
- [ ] Run Second Brain tests, security cases, the architecture test, and the full suite.

### Task 6: Full localization and email verification UX

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ta.arb`, affected presentation files, and auth tests.

**Interfaces:** Produces English/Tamil strings for all reachable user/admin screens and a verification flow that never calls authenticated resend while signed out.

- [ ] Add localization coverage that inventories visible labels and fails on remaining hard-coded reachable copy.
- [ ] Move user/admin strings into ARB resources and regenerate localization output.
- [ ] Add failing auth tests for signed-out resend, expired links, eligible resend, success, and safe failures.
- [ ] Implement contract-correct verification routing and resend eligibility.
- [ ] Run localization/auth tests, the architecture test, and the full suite.

### Task 7: AI, Blueprint recovery, revisions, and ZIP integrity

**Files:** Selectively reconcile Shayiny commits after `c43049b` and compatible Thikal AI/revision work into focused files.

**Interfaces:** Produces persistent job progress, verified extraction/generation states, Backend Blueprint v1 mapping, browser recovery, regeneration guards, history/restore where contracts exist, and structural ZIP validation.

- [ ] Import contributor tests in dependency order and record which fail against the checkpoint base.
- [ ] Integrate pure mapping/recovery/ZIP modules before presentation changes.
- [ ] Reconcile editor presentation with current autosave, session isolation, and approval memory.
- [ ] Gate candidate endpoints behind explicit unavailable states.
- [ ] Run focused tests, the architecture test, and the full suite.

### Task 8: Remaining administration frontend

**Files:** Split and extend `lib/features/administration/` repositories/pages/widgets and their tests.

**Interfaces:** Produces all independently achievable metadata-only modules, strict allowlists, MFA/session gates, and explicit dependency states for unresolved actions.

- [ ] Add failing tests for the 13-module navigation and unavailable-state matrix.
- [ ] Reconcile compatible contributor dashboard/account-management work with the existing console.
- [ ] Add metadata-only diagnostics/monitoring views where verified data exists.
- [ ] Add safe unavailable panels for settings, support, rollback, and mutations without contracts.
- [ ] Run admin/privacy tests, the architecture test, and the full suite.

### Task 9: Final verification and manual delivery

**Files:** Update `README.md`, `docs/FRONTEND_COMPLETION_AUDIT.md`, and this plan.

**Interfaces:** Produces evidence-backed completion status and exact manual commit/push commands.

- [ ] Run `dart format` over changed hand-authored Dart files.
- [ ] Run `flutter pub get` and `flutter gen-l10n`.
- [ ] Run `flutter analyze --no-fatal-infos` and report every remaining diagnostic.
- [ ] Run `flutter test` and report the exact pass/fail count.
- [ ] Run `flutter build web --release` and `git diff --check`.
- [ ] Verify the 300-line architecture test, branch, identity, remotes, status, and contributor refs.
- [ ] Report implemented work, remaining blockers, all changed files, manual commit commands, dry-run push verification, and the final `Varmitha` push command.
