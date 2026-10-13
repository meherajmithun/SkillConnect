# Development setup

## Prerequisites

Install Git, Node.js 22.13+ and Flutter with Dart compatible with
`mobile/pubspec.yaml`. PostgreSQL is used for deployment; local development
uses the built-in Node SQLite driver.

## First run

```sh
npm ci
npm run migrate
DEMO_PASSWORD='choose-a-strong-example-password' npm run seed
npm run dev
```

Create a staff account using `ADMIN_USERNAME`, `ADMIN_EMAIL` and
`ADMIN_PASSWORD` with `npm run admin`. The administration console is
`http://localhost:8000/admin/`.

For the Flutter web app, use another terminal:

```sh
cd mobile
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=ALLOW_HTTP=true
```

The optional root `.env` is automatically loaded by Node development, schema,
seed, administrator, import and push-worker commands. Environment variables
already exported in the shell take precedence. Never commit credentials.

## Planning prototype

Run `make prototype` and open `http://localhost:8082`. This sample HTML/JS
prototype is independent of the real Flutter app and API.

## Checks

```sh
npm run doctor
npm run check
npm test
make check-mobile test-mobile
```

Backend tests run against isolated SQLite databases. CI also tests PostgreSQL.
Real email/push/payment delivery, release signing and user acceptance require
their own configuration and checks.

## Phone testing

Keep the phone and computer on the same Wi-Fi. Run the Node server and enter
`http://YOUR_COMPUTER_IP:8000/api/` in the app server settings. If exact
`ALLOWED_HOSTS` is set, include the computer's Wi-Fi address. Public use needs
a hosted HTTPS server. The offline faculty APK works independently of hosting.

See [Android sharing](../ANDROID_SHARING.md), [faculty demo](../FACULTY_DEMO.md)
and [migration notes](../JAVASCRIPT_MIGRATION.md).
