# Flutter Web frontend ↔ Visual Studio 2026 / ASP.NET Core 10 backend

Flutter/Dart does NOT compile against .NET SDK 10.0.400. The backend targets `net10.0` and exposes HTTP JSON endpoints; Flutter Web consumes the same API.

Required backend base URL: `http://127.0.0.1:5264` (loopback; local demo only).

Implemented endpoints used by frontend:
- `GET /api/v1/projects`
- `POST /api/v1/projects` with `Idempotency-Key` header
- `GET /api/v1/projects/{id}/draft`
- `PUT /api/v1/projects/{id}/builder/steps/1` with `expectedVersion`

Backend CORS accepts `http://127.0.0.1:5310` and `http://localhost:5310`.

To run:
1. Open backend `.sln` in Visual Studio 2026, choose local demo profile and press **F5**.
2. Open frontend folder in VS Code (recommended for Dart) or use PowerShell terminal.
3. Run `powershell -ExecutionPolicy Bypass -File .\scripts\run_frontend_web.ps1`.
4. View `http://localhost:5310` in Chrome.

The UI layouts are Flutter widgets (not Visual Studio XAML / Blazor); no .NET SDK reference is required in `pubspec.yaml`. No real authentication, AI or full Builder steps 2-8 is implemented by these starters.
