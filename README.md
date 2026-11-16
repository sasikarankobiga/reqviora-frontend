# REQVIORA Frontend

Flutter Web frontend with feature-first Clean Architecture and a separate blueprint design renderer.

## Before running
This scaffold does **not** include Flutter-generated browser/engine/platform files. Install Flutter and run `flutter create --platforms=web --project-name reqviora_frontend .` in this directory; preserve the existing `lib` and config files. Then run `flutter pub get` and `flutter run -d chrome`.

The `31` `lib/features/*` directories each have presentation/domain/data layers. Place shared widgets in `lib/shared` and blueprint rendering in `lib/design_renderer`.

This is a starting structure, **not a full 137-screen implementation**.
