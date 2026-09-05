# Backend Operations

The commands in this guide modify live authentication or database data. Run them only from an authorized workstation with a private service-account key.

## Tool Setup

```powershell
Set-Location tools\firestore-seed
npm install
```

Set credentials only for the current PowerShell process:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\serviceAccountKey.json'
$securePassword = Read-Host 'New Super Admin password' -AsSecureString
$credential = [System.Management.Automation.PSCredential]::new('unused', $securePassword)
$env:BFP_SUPER_ADMIN_PASSWORD = $credential.GetNetworkCredential().Password
```

`BFP_SUPER_ADMIN_EMAIL` is optional and defaults to `akoangadmin@gmail.com`. The password must contain at least eight characters and has no source-code default.

## Repair or Rotate Super Admin

Keeps existing operational data and updates only the Super Admin authentication/profile records:

```powershell
npm run ensure-super-admin
```

## Seed Base Data

Creates or updates the Super Admin and base GIS collections without recreating legacy demo staff accounts:

```powershell
npm run seed
```

## Reset Legacy Accounts

Removes known legacy demo accounts and recreates only the configured Super Admin. This is destructive account maintenance:

```powershell
npm run reset-accounts
```

## Deploy Database Rules

Return to the repository root, then run:

```powershell
Set-Location ..\..
npx firebase-tools deploy --only firestore:rules --project gis-cross-platform
```

## Deploy Web App

Build the production Flutter web bundle from the repository root:

```powershell
flutter build web --release
```

Deploy the generated `build/web` directory:

```powershell
npx firebase-tools deploy --only hosting --project gis-cross-platform
```

The same hosted build serves Citizen, Barangay, BFP, and Admin routes. Access is enforced by the authenticated user role.

## Clear Temporary Secrets

```powershell
Remove-Item Env:BFP_SUPER_ADMIN_PASSWORD -ErrorAction SilentlyContinue
$credential = $null
$securePassword = $null
```

Never place the service-account JSON or a real `.env` file in the repository. The checked-in `.env.example` contains names and placeholders only.
