# REQVIORA Final Frontend Readiness

Date: 2026-11-28 (Asia/Colombo)

## Scope and evidence boundary

This assessment covers the Flutter frontend on `Varmitha` and the read-only backend contracts at `54daf30be57fcb76aaa76c4b3fed45f8c6d44cef`. Automated evidence is UNIT, WIDGET, MOCK_CONTRACT, STATIC, or BUILD evidence. It is not presented as LIVE_API or BROWSER_E2E evidence.

The frontend uses real `/api/...` contracts in production paths. Test fixtures remain under `test/`; no runtime failure is replaced with mock success. Tokens remain in memory, payment redirects are not trusted as payment proof, administrator billing requires server authorization/MFA, and unsupported operations are explicitly unavailable.

## User feature inventory

| Area | Implementation | Automated evidence | Live evidence |
|---|---|---|---|
| Authentication and account security | COMPLETE for current contracts | PASS | BLOCKED: backend/SMTP/test accounts unavailable |
| Personalized dashboard and profile identity | COMPLETE | PASS: Unicode/Tamil identity, greeting boundaries, session isolation | BLOCKED |
| Projects and workspace navigation | COMPLETE for current contracts | PASS | BLOCKED |
| Text/document/voice input | COMPLETE for implemented contracts | PASS | BLOCKED: storage/OCR/microphone/transcription provider unavailable |
| AI extraction and clarification | COMPLETE for current contracts | PASS | BLOCKED: provider authorization unavailable |
| Project sharing (FU05) | COMPLETE for current contracts | PASS | BLOCKED: SMTP and second authorized account unavailable |
| Builder Steps 01-08 | COMPLETE for current contracts | PASS | BLOCKED |
| Draft persistence/concurrency | COMPLETE | PASS: cross-section rebase, same-section fail-closed conflict | BLOCKED |
| Validation, approval, revisions and export | COMPLETE for current contracts | PASS | BLOCKED: live storage/export service unavailable |
| Second Brain | COMPLETE for current contracts | PASS | BLOCKED |
| MCP handoff (FU11) | COMPLETE for current fixed-scope contract | PASS | BLOCKED: MCP transport/client unavailable |
| PayHere billing (FU12) | COMPLETE for current contracts | PASS | BLOCKED: authorized sandbox/callback unavailable |

## Administrator inventory

| Area | Implementation | Contract limitation |
|---|---|---|
| Authentication, MFA and recovery | COMPLETE | Live identity/MFA unavailable |
| Dashboard, users, roles, projects, audit | COMPLETE for current metadata contracts | Live authorization unavailable |
| FA06 MCP grants | COMPLETE | Backend supports search/state/project filters and emergency revoke only |
| FA07 export diagnostics | COMPLETE | Backend supports status/project/date filters; no broader sorting contract |
| FA08 validation monitoring | COMPLETE for aggregate APIs | No project directory/details or rule/severity analytics |
| FA10 AI queue monitoring | COMPLETE for read APIs | No administrator retry/cancel endpoints |
| FA11 settings | COMPLETE for allowlisted setting contract | Not a general environment editor |
| FA12 incidents | COMPLETE | No support ticket/conversation/internal-note or priority-update API |
| FA13 profile/sessions | COMPLETE for supported fields/actions | Profile/session DTOs omit several requested descriptive fields |
| FA14 billing | COMPLETE for sandbox monitoring/review APIs | No admin entitlement API or real refund execution contract |

## Critical UX and quality

- Actual profile display name is shared across dashboard, account, sidebar/account surfaces, and relevant admin presentation.
- Unicode-aware initials are used when the backend supplies no valid avatar URL.
- Greetings use local time and reschedule at 05:00, 12:00, 17:00, and 21:00, including application resume.
- Backend availability is represented separately from authentication state.
- Browser tokens are not persisted in script-readable storage. A full page refresh therefore requires sign-in until the backend supplies an HttpOnly-cookie restoration contract.
- Post-login restoration preserves validated project IDs, Builder steps, tabs, and query parameters. It rejects external, unknown, public-auth, invitation, fragment, and malformed destinations.
- Responsive/accessibility/localization suites cover mobile, tablet, desktop, keyboard interaction, contrast, and English/Tamil flows.

## Architecture and known debt

Feature domain/data/application/presentation boundaries, Riverpod session scoping, GoRouter guards, typed DTOs, and the shared `ApiClient` are preserved. Pre-existing hand-authored files exceed the documented 300-line target. The largest is `lib/features/workspace/presentation/authoring_page.dart` at roughly 3,841 lines. Other notable files include prebuilder panels, authentication screens, simulated preview, and several admin pages. These should be decomposed after submission with behavior-preserving tests; a deadline-time repository-wide rewrite is not justified.

## Release assessment

Local source and automated release readiness are PASS: analyzer 0/0/0, 853/853 tests, G1 validation and the non-demo release build pass on the CI-pinned SDK. Production readiness remains BLOCKED until authorized isolated LIVE_API/BROWSER_E2E verification covers SMTP, database persistence, storage/OCR, AI, MCP, PayHere callback verification, and administrator MFA workflows.
