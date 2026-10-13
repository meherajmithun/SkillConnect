# SkillConnect

**Find skills. Connect locally. Grow your business.**

A service marketplace with a **Flutter/Dart frontend and JavaScript backend**.
Customers discover professionals, compare work, request quotations, book services,
message and review completed work. Professionals manage profiles, appointments
and service/area promotions. Staff use the Node.js administration console.

The latest live Android build is `dist/SkillConnect-v2.1.0.apk`. Both roles can
sign in by email or username and opt in to saved email/password suggestions.
Providers start in My business, select their services and areas, and can edit
portfolio projects. See the [role audit and release checks](docs/ROLE_AUDIT_2_1_0.md).

## Stack

- Flutter/Dart for Android, iOS and web.
- Node.js 22.13+ and Express 5, with JavaScript ES modules.
- PostgreSQL for deployment; built-in Node SQLite for local development.
- JWT access/refresh sessions, scrypt password hashing, role/participant permissions.
- Optional SMTP, Firebase Cloud Messaging and SSLCommerz hosted checkout.

## Run locally

Install Node.js 22.13+ and a stable Flutter SDK compatible with the mobile manifest.

```sh
npm ci
npm run migrate
# For a fresh database; existing accounts are preserved:
DEMO_PASSWORD='choose-a-strong-example-password' npm run seed
npm run dev
```

The API runs on **http://localhost:8000/api/** and listens on all local network
interfaces by default. Node commands load an optional root `.env` automatically.
Copy `.env.example` and edit it for your environment.

Create a staff account:

```sh
ADMIN_USERNAME=admin ADMIN_EMAIL=admin@example.com \
ADMIN_PASSWORD='choose-a-strong-admin-password' npm run admin
```

Sign in at **http://localhost:8000/admin/**. The staff console manages account
activation, professional verification, categories, areas, review visibility,
promotion packages/payments and reports, and shows bookings and metrics.

Run Flutter in another terminal:

```sh
cd mobile
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=ALLOW_HTTP=true
# Android emulator:
flutter run --dart-define=ALLOW_HTTP=true --dart-define=API_URL=http://10.0.2.2:8000/api/
```

For a phone on the same Wi-Fi, use the computer's Wi-Fi address in the app's
server settings. Keep the Node server running. See [Android sharing](docs/ANDROID_SHARING.md).

## Offline faculty demo

Install `dist/SkillConnect-demo-v1.2.1.apk` to explore the Flutter app without
hosting. Sample changes stay on the phone. Account → Switch demo account provides
Customer and Professional accounts. See [faculty walkthrough](docs/FACULTY_DEMO.md).
The frontend API is compatible with the new JavaScript backend.

## Database import

The migration imported this workspace's existing local accounts, profiles,
bookings, reviews and catalogue into `backend/data/skillconnect.sqlite3`.
A read-only backup is kept at `backend/data/legacy.sqlite3`. Existing passwords
continue to work; sign in again because old sessions were retired.

For another existing installation, import its old SQLite backup into an empty
new database before seeding:

```sh
npm run import-legacy -w backend -- /absolute/path/to/backup.sqlite3
```

The import uses Node.js only and refuses to overwrite an existing target database.
Back up the database and media before running it. See [migration notes](docs/JAVASCRIPT_MIGRATION.md).

## PostgreSQL / Docker

```sh
cp .env.example .env
# Set a random JWT_SECRET, strong POSTGRES_PASSWORD and production settings.
docker compose up --build -d
```

The API creates its schema on startup. Pass admin/seed credentials explicitly
when running the corresponding commands inside the container:

```sh
docker compose exec -e ADMIN_USERNAME=admin -e ADMIN_EMAIL=admin@example.com \
  -e ADMIN_PASSWORD='choose-a-strong-admin-password' api node src/commands.js admin
docker compose exec -e DEMO_PASSWORD='choose-a-strong-example-password' \
  api node src/commands.js seed
```

Production requires PostgreSQL, a strong JWT secret, exact host/origin settings
and HTTPS from a trusted reverse proxy. Store media on a persistent volume or
object storage; the Node server serves its configured media directory.
Back up both PostgreSQL and media. Use your own Android signing key for distribution.

## Render hosting

The root [Render Blueprint](render.yaml) deploys the Node.js API and PostgreSQL
without sample accounts. See [Render deployment](docs/RENDER_DEPLOYMENT.md) for
account connection, phone setup, database initialization and free-plan limits.
Once hosted, the phone uses the HTTPS API without the computer staying on.

## Integrations

Email codes print only in local console mode; set `EMAIL_MODE=smtp` and SMTP
credentials for delivery. Configure Firebase credentials and run
`npm run push-worker` for native push. Run one worker; retries are tracked per
device and delivery is at least once. Configure merchant credentials and HTTPS
callbacks to enable SSLCommerz. Manual promotion payment confirmation remains
available. Live provider/device checks still require your own credentials.

## Validate

```sh
npm run check
npm test
make check-mobile test-mobile
```

Backend tests exercise real HTTP endpoints with SQLite. CI repeats them against
PostgreSQL. They cover auth/session revocation, permissions, request lifecycles,
concurrent booking/refresh protection, uploads, moderation, payments, push and
legacy data import. Provider transports are mocked in tests.

See [API](docs/API.md), [project structure](docs/PROJECT_STRUCTURE.md),
[proposal coverage](docs/PROPOSAL_COVERAGE.md) and [Sprint 1 planning](docs/sprint-1/README.md).
Run `make help` for development commands.
