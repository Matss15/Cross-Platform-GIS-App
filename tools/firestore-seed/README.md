# Account and Seed Tools

Privileged Node.js utilities for Super Admin maintenance and base GIS data.

```text
firestore-seed/
  lib/tool-config.mjs       Shared credential and Admin SDK setup
  ensure-super-admin.mjs    Repair or rotate Super Admin
  reset-accounts.mjs        Remove legacy accounts and recreate Super Admin
  seed-firestore.mjs        Seed Super Admin and base GIS data
  .env.example              Variable names and safe placeholders
```

No script contains or prints a default password. Set `BFP_SUPER_ADMIN_PASSWORD` and `GOOGLE_APPLICATION_CREDENTIALS` in the current process before running an npm command.

See [Backend Operations](../../docs/OPERATIONS.md) for complete instructions and safety notes.
