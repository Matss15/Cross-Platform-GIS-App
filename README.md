# BFP Rosario GIS

Cross-platform fire incident reporting and emergency response GIS for BFP Rosario, Batangas.

## Start Here

- [Documentation index](docs/README.md)
- [Login accounts and access](docs/LOGIN_ACCOUNTS.md)
- [Local development and builds](docs/DEVELOPMENT.md)
- [Backend operations](docs/OPERATIONS.md)
- [Security demonstration](docs/SECURITY_DEMO_GUIDE.md)

## Repository Layout

```text
assets/                    App images and icons
docs/                      Project, access, operations, and demo guides
lib/
  app.dart                 Shared Flutter library entry and part registry
  app/                     Root app widget and theme
  config/                  Rosario reference data
  core/                    App-wide constants, models, routing, and services
  features/                Role and capability-owned UI
test/                      Automated Flutter tests
tools/
  firestore-seed/          Privileged account and base-data maintenance
android, ios, linux,
macos, web, windows/       Flutter platform projects
```

Keep generated output in `build/` and `.dart_tool/`. Do not add application code to platform folders unless the change is platform-specific.

## Quick Check

```powershell
flutter pub get
flutter analyze
flutter test
```
