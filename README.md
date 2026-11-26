# REQVIORA — Flutter Web Frontend V4 (Clean Architecture)

Web workspace for the REQVIORA design/Second Brain project. Uses the **.NET SDK 10.0.400** backend REST API; Flutter is a separate Dart toolchain and is NOT built by Visual Studio's C# compiler.

## Layering

- `lib/core/`: Configuration, network adapter and in-memory authentication session.
- `lib/features/*/domain/`: Models, repository contracts and platform abstractions.
- `lib/features/*/application/`: Riverpod providers/use-case coordination.
- `lib/features/*/data/`: API, browser file-picker and download adapters.
- `lib/features/*/presentation/`: REQVIORA dashboard, forms, editor views and safe mock renderer.
- `lib/app/`: Navigation, theme, responsive sidebar and common design components.

Browser adapters use conditional imports so `flutter test` on the VM can select no-op platform stubs. **Flutter Web only** is the approved application target; Web/Mobile/Desktop are preview profiles inside it.

## Local run

```powershell
cd reqviora-frontend
flutter doctor
flutter create . --platforms=web --project-name reqviora_frontend
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 5310 --dart-define=REQVIORA_LOCAL_DEMO=true --dart-define=REQVIORA_API_BASE_URL=http://127.0.0.1:5264
```

First start the backend using its Visual Studio 2026 F5 launch profile. Browser URL: `http://localhost:5310`.

To test real Identity account registration/login in local dev, set `REQVIORA_LOCAL_DEMO=false` and use the backend with demo mode disabled (default). Access and refresh tokens live in memory and are discarded on browser refresh/sign-out. The frontend includes refresh/retry, OTP login, password recovery/reset, email verification and authenticator MFA setup; the connected backend must expose the matching `/api/auth`, `/api/account-security` and `/api/security/mfa` routes.

## Functional journey in this milestone

`Dashboard → Create Project → Overview → Input Studio (text, TXT/DOCX upload) → Local rule suggestions + owner review → Builder Steps 01–08 → Template Blueprint + Mock Preview → Validation → Draft ZIP`.

The appearance, responsive sidebar, cards and screens follow the approved REQVIORA purple/blue design system. **No synthetic success or approval state is displayed for unimplemented services.**

## Pending product functionality

Tamil/English transcription, external AI, AI UI generation, revision history, complete permission invitations, MCP handoff and the remaining Super Admin mutations/monitoring require confirmed backend contracts. Browser-audio preview, a local graphical route canvas and a safe local documentation viewer are still frontend work; they are not described as backend-blocked. The component editor now includes theme tokens/modes, screen access roles, editable local Blueprint preview, nested draft preservation, autosave, accessibility and approval locks. See `docs/FRONTEND_COMPLETION_AUDIT.md` for package-level evidence and blockers.
