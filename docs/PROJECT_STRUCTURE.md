# Project structure

SkillConnect uses a Flutter frontend and JavaScript Node.js backend.

```text
backend/
  src/
    server.js          HTTP startup and shutdown
    app.js             Express middleware and route registration
    config.js          Environment configuration
    db.js              PostgreSQL / SQLite transaction adapter
    schema.js          Portable relational schema
    auth.js            JWT rotation, passwords, recovery and email verification
    marketplace.js     Discovery, profiles, bookings, quotes, messages and reviews
    uploads.js         Validated portfolio images and media ownership
    payments.js        SSLCommerz checkout, validation and reconciliation
    push-worker.js     Per-device FCM delivery and retries
    admin.js           Staff administration API
    seed.js            Repeatable example data
    import-legacy.js   Read-only import of old SQLite data using Node
    commands.js        Schema, seed, administrator and import commands
  public/              Browser administration console
  test/                Node test runner HTTP/integration tests
  scripts/check.js     JavaScript syntax checks
  data/                Ignored local database and migration backup
  media/               Ignored portfolio photos
  credentials/         Ignored provider credentials
mobile/
  lib/                 Flutter app and screens
  lib/api.dart         Live Node API client and isolated demo switch
  lib/demo.dart        Local offline demo store
  test/                Flutter widget and demo tests
docs/                   API, migration, faculty and planning documents
scripts/                Node development doctor and prototype server
package.json            Workspace commands
package-lock.json       Locked JavaScript dependencies
compose.yaml            Node API + PostgreSQL + optional push worker
```

Start with the root README. `npm ci` installs the JavaScript dependencies,
`npm run migrate` initializes the schema, and `npm run dev` starts the API.
Flutter runs separately; live screens use the API and demo mode stays on-device.
