# REQVIORA Frontend Run and Deployment Guide

## Required toolchain

- CI authority: Flutter 3.47.6, Dart 3.13.5.
- Run from the frontend repository root.

```powershell
flutter pub get
flutter gen-l10n
flutter analyze --no-pub
flutter test --no-pub
python contracts/g1/tests/validate_pack.py
```

## Local connected run

Start an authorized backend on `http://127.0.0.1:5264`, then:

```powershell
flutter run -d chrome --web-port 3000 `
  --dart-define=REQVIORA_API_BASE_URL=http://127.0.0.1:5264 `
  --dart-define=REQVIORA_LOCAL_DEMO=false
```

The backend must explicitly allow the chosen frontend origin through CORS. Do not put passwords, tokens, SMTP credentials, provider keys, or PayHere merchant secrets in `--dart-define` values or frontend assets.

## Production build

```powershell
flutter build web --release --no-pub `
  --dart-define=REQVIORA_API_BASE_URL=https://api.example.com `
  --dart-define=REQVIORA_LOCAL_DEMO=false
```

Production mode requires a real HTTPS API URL. Replace the example host during deployment. Serve `build/web` over HTTPS and configure the web server to fall back unknown application paths to `index.html` so GoRouter deep links and refreshes work.

## Runtime and security behavior

- Access/refresh tokens remain in memory and are never placed in browser local/session storage.
- Until the backend provides a secure HttpOnly-cookie restoration contract, a full browser process/page refresh requires sign-in. The validated destination is then restored for known authenticated routes.
- Backend authorization remains authoritative; frontend visibility checks do not grant access.
- `REQVIORA_LOCAL_DEMO=false` is mandatory for connected/release verification.
- PayHere success redirects are never payment proof; only backend status/callback verification can grant entitlement.

## Deployment checklist

1. Set the HTTPS API origin and keep local demo disabled.
2. Configure exact frontend origins in backend CORS; do not use wildcard credentials.
3. Configure TLS, CSP/security headers, cache policy, and SPA fallback at the hosting layer.
4. Verify assets and `voice_recorder.js` load without mixed content.
5. Supply backend-only SMTP, storage/OCR, AI, MCP, signing, database, and PayHere configuration through the backend secret store.
6. Run the full automated gate and isolated live matrix before production promotion.
