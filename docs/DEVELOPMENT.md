# Development and Builds

Run commands from the repository root.

## Setup

```powershell
flutter pub get
```

## Run

Web and Admin portal:

```powershell
flutter run -d chrome
```

Android device or emulator:

```powershell
flutter run -d android
```

Windows desktop:

```powershell
flutter run -d windows
```

## Verify

```powershell
flutter analyze
flutter test
```

## Release Builds

```powershell
flutter build web --release
flutter build apk --release
flutter build windows --release
```

Outputs:

```text
build/web/
build/app/outputs/flutter-apk/app-release.apk
build/windows/x64/runner/Release/
```
