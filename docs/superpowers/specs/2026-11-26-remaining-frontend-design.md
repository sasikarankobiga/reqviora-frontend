# REQVIORA Remaining Frontend Design

## Intent

Continue from the verified dirty `Varmitha` tree, preserve its account-security, administration, editor, localization, and test work, then integrate only compatible contributor functionality. The resulting frontend must not fabricate backend success or expose private content.

## Constraints

- Work only in `C:\Users\UT011612\REQVIORA_Varmitha` on `Varmitha`.
- Do not reset, clean, overwrite, commit, or push automatically.
- Preserve contributor attribution and reconcile changes feature by feature.
- Use only verified existing API contracts; unavailable server operations render explicit unavailable states.
- Every hand-authored Dart file under `lib/` and `test/` must contain at most 300 physical lines, including imports and comments. Generated localization Dart files are exempt because `flutter gen-l10n` owns them.
- Preserve all existing tests and add test-first coverage for new behavior.

## Approach

Use a checkpoint-first selective integration. The developer manually commits the three already-verified logical groups before conflict-prone work starts. After that, add a file-length architecture test, split oversized files by responsibility, and integrate contributor commits in small functional slices rather than merging either feature branch wholesale.

Rejected alternatives:

- A wholesale merge would overwrite or conflict with the current session-isolation, editor-safety, administration, and localization work.
- Copying the contributor branch tree would lose reviewable attribution boundaries and could introduce candidate API contracts as if they were approved.
- Deferring the 300-line rule until the end would make every later conflict harder to resolve.

## Delivery slices

1. Protect the current dirty implementation with three manual checkpoint commits.
2. Enforce and satisfy the 300-line architecture rule.
3. Integrate browser voice capture without simulated transcription.
4. Integrate the local graphical navigation editor and verified persistence only.
5. Add a safe local Second Brain viewer for real available project data.
6. Finish localization and signed-out email-verification UX.
7. Reconcile compatible AI, Blueprint recovery, revision, and ZIP-integrity work.
8. Complete independently achievable admin UI and explicit dependency states.
9. Run the complete analyzer, test, build, diff, and manual-delivery gate.

## Safety model

- Browser media resources are stopped and released on cancellation, navigation, and disposal.
- Markdown is rendered without executing embedded HTML or scripts.
- JSON is displayed as text/tree data, never evaluated.
- Archives are validated but never extracted in the browser.
- Tokens, recovery material, and raw credentials stay memory-only and out of logs.
- Account changes invalidate requests, provider caches, approval memory, and locally recovered private drafts.

## Success criteria

- No hand-authored Dart file under `lib/` or `test/` exceeds 300 lines.
- Existing 304 tests remain green and new behavior has RED-to-GREEN coverage.
- `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build web --release`, and `git diff --check` succeed.
- The audit distinguishes implemented, locally available, and backend-blocked functionality with exact evidence.
