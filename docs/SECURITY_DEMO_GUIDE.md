# Security Demonstration Guide

## Login and Password Handling

1. Open the Citizen login and enter a valid account.
2. Show that the password field is obscured and passed directly to the authentication SDK in `lib/features/auth/login_screen.dart`.
3. Show the user profile record. It contains account and role data, but no plaintext password or password hash.
4. Explain that password hashing occurs in the managed authentication backend, not in the Flutter client or GIS database.

Do not expose or export real password hashes during a presentation. The absence of a password field in the user profile and the provider's Authentication user record are the correct live evidence.

Official reference: https://firebase.google.com/docs/auth/admin/import-users

## Role-Based Access Control

1. Sign in as a Citizen and show Home, Report, Map, and Profile.
2. Sign out and sign in as BFP or Admin to show its different destinations.
3. Select the wrong role for an account. The app signs out instead of opening that workspace.
4. Show `lib/features/auth/role_gate.dart`, `lib/features/shared/shell.dart`, and `firestore.rules` to demonstrate that UI routing and database authorization both enforce roles.

## Privacy, Terms, and Consent

1. Open Privacy Notice and Terms of Use from login.
2. Open Citizen registration and show required consent.
3. Register a disposable test account and show `policyVersion` and `policyAcceptedAt` in its profile.
4. Show the matching validation in `firestore.rules`.

## Logout, Timeout, and Protected Routes

1. Sign in, then use Sign out.
2. Show that the auth-state listener returns to login and no protected role content remains rendered.
3. Explain the automatic 30-minute inactivity timeout.
4. Show the `Signed out` or `Session timed out` activity log entry.

Client sign-out removes the local authenticated session. Global refresh-token revocation across devices requires a privileged Admin SDK backend operation.

Official reference: https://firebase.google.com/docs/auth/admin/manage-sessions
