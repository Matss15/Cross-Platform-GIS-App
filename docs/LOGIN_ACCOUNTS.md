# Login Accounts and Access

## Account Ownership

| Role | Provisioning | App entry |
| --- | --- | --- |
| Citizen | Self-registration or Admin portal | Select `Citizen` |
| Barangay Staff | Super Admin through `Accounts` | Select `Brgy` |
| BFP Personnel | Super Admin through `Accounts` | Select `BFP` |
| Super Admin | Privileged maintenance tool | Web only; select `Admin` or open `/#/admin` |

The configured Super Admin email is `akoangadmin@gmail.com`. Its password is intentionally not stored in this repository or printed by maintenance scripts. Keep the current credential in an approved private password manager.

## Login Procedure

1. Open the correct role segment.
2. Enter the account email and password.
3. The app verifies both the authenticated account and its user-profile role.
4. If the selected role is wrong, the app signs out and identifies the correct workspace.

Admin access is web-only. Citizen, Barangay, and BFP workspaces are available on supported mobile and desktop targets.

## Account Creation

Citizen:

1. Select `Citizen` and open `Register citizen`.
2. Complete the profile fields.
3. Review and accept the Privacy Notice and Terms of Use.
4. Create the account and keep the credential private.

Managed account:

1. Sign in as Super Admin on web.
2. Open `Accounts`.
3. Choose Citizen, Barangay, or BFP.
4. Create the profile and provide the credential directly to its owner.

## Password Recovery

Use `Forgot password?` on the login screen. Password changes occur in the authentication service; changing or deleting a database profile does not change the login password.

## Credential Rules

- Never commit passwords, service-account keys, screenshots of credentials, or exported authentication records.
- Do not share one staff account between multiple people.
- Rotate temporary or previously documented passwords before a live demonstration.
- Disable accounts that no longer require access.
- Keep a private account register containing owner, role, email, issue date, and status. Do not put passwords in that register.

For Super Admin repair or rotation, follow [Backend Operations](OPERATIONS.md).
