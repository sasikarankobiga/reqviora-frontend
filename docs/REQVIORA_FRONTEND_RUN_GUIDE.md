# REQVIORA Frontend Run Guide

Updated: 2026-11-28 (Asia/Colombo)

## Prerequisites

- Flutter 3.47.6 (the version pinned by `.github/workflows/ci.yml`)
- A backend matching commit `54daf30be57fcb76aaa76c4b3fed45f8c6d44cef` or a compatible later contract
- Chrome or another supported Flutter Web browser
- Authorized test identities for any live authenticated checks

Never place credentials in source, `--dart-define` values committed to Git, screenshots or documentation.

## Install and generate

```powershell
flutter --version
flutter pub get
flutter gen-l10n
```

## Local integration run

Start the backend using its own documented environment configuration, database and provider settings. Configure its CORS allowlist for the exact frontend origin `http://localhost:3000` during local development.

```powershell
flutter run -d chrome --web-port 3000 `
  --dart-define=REQVIORA_API_BASE_URL=http://127.0.0.1:5264 `
  --dart-define=REQVIORA_LOCAL_DEMO=false
```

Local HTTP is for loopback development only. Production builds must use an HTTPS API URL; the frontend API client rejects insecure non-loopback production endpoints.

## Verification

```powershell
flutter analyze --no-pub
flutter test --no-pub
python contracts/g1/tests/validate_pack.py
flutter build web --release --no-pub `
  --dart-define=REQVIORA_API_BASE_URL=https://api.example.invalid `
  --dart-define=REQVIORA_LOCAL_DEMO=false
```

Replace `https://api.example.invalid` only with the real HTTPS deployment endpoint in the deployment environment.

## Deployment requirements

- Serve the web assets over HTTPS.
- Use an exact HTTPS API origin and exact-origin backend CORS configuration.
- Keep `REQVIORA_LOCAL_DEMO=false`.
- Supply backend secrets only through the backend deployment secret store.
- Configure SMTP, document parsing, transcription, AI, object storage, MCP and PayHere in their owning backend/provider environments.
- Complete the secure cookie-session backend dependency before claiming browser-refresh session recovery.
- Verify email, MFA, payment and refund flows only with explicitly authorized sandbox/test accounts.

## Troubleshooting

- HTTP 401: sign in with an authorized verified identity; do not bypass verification or MFA.
- HTTP 403: the account lacks the required role/project permission.
- HTTP 409: reload the authoritative resource and resolve the displayed concurrency conflict.
- HTTP 429: respect the server retry interval; do not create an unbounded retry loop.
- Browser reload returns to sign-in: expected until the backend supplies the documented secure server-managed refresh session.
