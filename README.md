# SkillConnect

**Find skills. Connect locally. Grow your business.**

SkillConnect is a service marketplace. Customers can find professionals, request
quotes, book services, and leave reviews. Professionals can manage their profiles,
appointments, and promotions. Staff have a separate administration page.

The app has two parts that run together:

| Part | Folder | What it does |
| --- | --- | --- |
| Backend | `SkillConnect/` | Node.js API and local database |
| Frontend | `SkillConnect/mobile/` | Flutter app shown in Chrome or on a phone |

## Run locally in VS Code

### 1. Install the tools

Install [Node.js](https://nodejs.org/) **22.13 or newer**, the
[Flutter SDK](https://docs.flutter.dev/get-started/install), and Chrome. Check
that they work in a terminal:

```sh
node --version
npm --version
flutter --version
```

Open the `SkillConnect` folder in VS Code. You will need **two terminals**:
choose **Terminal → New Terminal** twice. Keep both running while you use the app.

### 2. Start the backend in Terminal 1

These commands run from the **SkillConnect repository folder**, which contains
`package.json`. If your terminal is in `varsity-project`, first run
`cd SkillConnect`:

```sh
cd SkillConnect
pwd
npm ci
npm run migrate
npm run dev
```

The `pwd` output should end in `/varsity-project/SkillConnect`. If VS Code
already opened the terminal in `SkillConnect`, skip `cd SkillConnect`.
`npm ci` installs dependencies, and `npm run migrate` prepares the local
database. You normally run those two commands only on first setup or when the
project's dependencies or database schema change. For everyday use, run
`npm run dev`.

Leave Terminal 1 open. Visit <http://localhost:8000/api/health/> in Chrome to
check that the backend is running. The staff page is at
<http://localhost:8000/admin/>; it needs a staff account (see below).

### 3. Start Flutter in Terminal 2

These commands run from the **mobile folder**, which contains `pubspec.yaml`.
In a new VS Code terminal that starts in `SkillConnect`, run:

```sh
cd mobile
pwd
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=ALLOW_HTTP=true
```

The `pwd` output should end in `/varsity-project/SkillConnect/mobile`. If
Chrome does not open automatically, visit <http://localhost:8080>.
`flutter pub get` installs Flutter dependencies; rerun it when those
dependencies change. Keep Terminal 2 open while coding. Save a Dart file and
press `r` in Terminal 2 for **hot reload**, or `R` for **hot restart**.

The browser app uses the backend at `http://localhost:8000/api/`. Both
terminals must stay running for features such as registration and sign-in.

### Common problems

| Message or symptom | What to check |
| --- | --- |
| `No pubspec.yaml file found` | Run `cd mobile` from `SkillConnect`, then run the Flutter command again. |
| `Cannot reach SkillConnect` | Make sure `npm run dev` is still running in Terminal 1. Open <http://localhost:8000/api/health/> to check it. |
| `cd SkillConnect: no such file or directory` | You may already be inside `SkillConnect`. Run `pwd` and look for `package.json` in the current folder. |
| Chrome does not launch | Check that Chrome is installed and run `flutter doctor` for Flutter setup advice. |

## Run on Android instead of Chrome

Start the backend as shown above. Start an Android emulator, then run this from
`SkillConnect/mobile`:

```sh
flutter run --dart-define=ALLOW_HTTP=true --dart-define=API_URL=http://10.0.2.2:8000/api/
```

`10.0.2.2` is how the Android emulator reaches the backend on your computer.
For a physical phone on the same Wi-Fi, use your computer's Wi-Fi address in
the app's server settings. See [Android sharing](docs/ANDROID_SHARING.md).

## Optional setup

### Add sample accounts and data

From `SkillConnect`, run the following in a separate terminal. Choose your own
sample password:

```sh
DEMO_PASSWORD='choose-a-strong-example-password' npm run seed
```

Seeding preserves existing accounts. The separate
[offline demo APK](dist/SkillConnect-demo-v1.2.1.apk) works without a backend;
see the [faculty walkthrough](docs/FACULTY_DEMO.md).

### Create a staff account

From `SkillConnect`, run:

```sh
ADMIN_USERNAME=admin ADMIN_EMAIL=admin@example.com \
ADMIN_PASSWORD='choose-a-strong-admin-password' npm run admin
```

Then sign in at <http://localhost:8000/admin/>. Staff can manage accounts,
verification, categories, areas, reviews, promotions, and reports.

### Configure the backend

The local backend uses a SQLite database, so PostgreSQL is not required for
local development. For custom settings, copy `.env.example` to `.env` in
`SkillConnect` and edit it. The Node commands load that file automatically.

## Project layout

| Path | Purpose |
| --- | --- |
| `mobile/` | Flutter app for Android, iOS, and web |
| `backend/` | Node.js and Express API, admin page, and database code |
| `docs/` | API, setup, deployment, and project documentation |
| `dist/` | Built Android APKs |

The current live Android build is `dist/SkillConnect-v2.1.0.apk`. See the
[role audit and release checks](docs/ROLE_AUDIT_2_1_0.md) for what it covers.

## Checks for contributors

Run backend checks from `SkillConnect`:

```sh
npm run check
npm test
```

Run Flutter checks from `SkillConnect/mobile`:

```sh
flutter analyze
flutter test
```

## Deployment and further reading

Local development uses SQLite. Deployment can use PostgreSQL with
[Docker Compose](compose.yaml) or the [Render Blueprint](render.yaml). Follow
the [Render deployment guide](docs/RENDER_DEPLOYMENT.md) for hosting steps and
free plan limits. Production also needs a strong JWT secret, HTTPS, persistent
database and media storage, and your own Android signing key.

If you are importing an older SQLite database, follow the
[migration notes](docs/JAVASCRIPT_MIGRATION.md) before seeding. For email,
push notifications, and payments, configure the corresponding credentials;
local email codes appear in the backend terminal by default.

More detail: [API](docs/API.md),
[project structure](docs/PROJECT_STRUCTURE.md),
[proposal coverage](docs/PROPOSAL_COVERAGE.md), and
[Sprint 1 planning](docs/sprint-1/README.md). Run `make help` to list
development commands.
