# 1.6 Development environment setup

## Observed local baseline

Verified on 10 October 2026: macOS arm64, Python **3.12.15**, Django **5.2.17**,
Flutter **3.47.2 stable**, Dart **3.13.2**. Dependencies are declared in
`backend/requirements*.txt` and `mobile/pubspec.yaml`/`pubspec.lock`.
Chrome and macOS targets were detected; no Android emulator or iOS simulator was
available. The project includes Android, iOS and web scaffolding, not a macOS app.

Backend checks and both test suites passed on the existing environment; this is
not a claim that a new machine or native build was tested. See [VALIDATION.md](VALIDATION.md).

## First-time setup

Install Git, Python 3.12+ and Flutter with Dart 3.13.2+ (within the manifest's
supported major version). Chrome is enough for the web preview. Android needs
Android Studio/SDK and a configured emulator or connected device. iOS needs
Xcode, its command-line tools and a simulator/device on macOS.

From the repository root:

```sh
python3.12 -m venv .venv
source .venv/bin/activate
make install
make doctor
make migrate
```

`make install` installs backend development dependencies and runs `flutter pub
get`. It does not migrate, seed, start servers or replace existing environment
files. `make doctor` prints local tool/dependency readiness without showing secrets.
`make` is optional: its recipes are plain commands shown in the root Makefile.

For this machine's existing environment, use `PYTHON=.venv312/bin/python` on Make
commands, for example `make doctor PYTHON=.venv312/bin/python`.

Seed example data with a password you choose (at least 12 characters). Read it
without echoing it or putting it in shell history:

```sh
read -s DEMO_PASSWORD
export DEMO_PASSWORD
make seed
unset DEMO_PASSWORD
```

Type the password and press Enter after `read`. In zsh/bash the input is hidden.
Demo accounts: `customer`, `rahim`, `sadia`, `karim`, `farzana`, `imran`, `tanim`.
The seeder does not overwrite existing passwords. Keep your chosen password
private; do not commit it. Staff access is separate:

```sh
python backend/manage.py createsuperuser
```

No seeding/password reset is necessary if the local demo database already exists.

## Run the actual app

Terminal 1, with the virtual environment activated:

```sh
make backend
```

Terminal 2:

```sh
make mobile
```

The backend listens on port 8000; Flutter web opens **http://localhost:8080**.
Health: **http://localhost:8000/api/health/**. Admin:
**http://localhost:8000/admin/**. Stop a foreground server with Ctrl+C; quit the
Flutter run process with `q`. Flutter's `r` command performs hot reload.

Use the app toolbar's server connection action to select/test the correct API
address. Switching servers signs out the current account.

| Client | API address | Extra setup |
| --- | --- | --- |
| Chrome on this computer | `http://localhost:8000/api/` | Port 8080 matches default CORS origins |
| Android emulator | `http://10.0.2.2:8000/api/` | Configured/running emulator and local HTTP define |
| iOS simulator | `http://localhost:8000/api/` | Xcode, iOS dependencies and local transport configuration |
| Physical phone | `http://COMPUTER_LAN_IP:8000/api/` | Same Wi-Fi, reachable server/firewall, IP included in ALLOWED_HOSTS |

Android example after starting the emulator:

```sh
cd mobile
flutter devices
flutter run -d DEVICE_ID --dart-define=ALLOW_HTTP=true --dart-define=API_URL=http://10.0.2.2:8000/api/
```

Native setup/build details: [Android sharing](../ANDROID_SHARING.md) and
[integration configuration](../APP_UPDATES.md). HTTP is a local development option;
production builds use HTTPS.

## Run the Sprint 1 phone prototype

```sh
make prototype
```

Open **http://localhost:8082** beside the editor. This serves only the prototype
directory on loopback and needs no backend. It is an interactive design fixture,
not a Flutter live-reload session. `python3 -m http.server 8082 --bind 127.0.0.1
--directory docs/sprint-1/prototype` is the equivalent command (on one line).
Set `PROTOTYPE_PORT=8083` if needed. The HTML also works directly from disk.

## Configuration

SQLite is the default for local Django commands. `.env.example` is a template for
Docker Compose; Django does **not** automatically load `.env` for local commands.
Export needed values in the shell before starting Django. Copy/edit the template
only when configuring Docker or keeping your own local settings.

Required for basic local work: no external secrets; `DEBUG=true` default and local
database are sufficient. Production requires a strong `SECRET_KEY`, PostgreSQL,
allowed hosts/origins and HTTPS. Optional providers:

- Email uses console delivery during local development.
- Promotions can use staff payment confirmation without gateway credentials.
- Notifications work in-app without native Firebase/APNs setup.

Do not include real credentials in documentation or fixtures. Existing ignore
rules cover `.env`, demo-password files, databases and provider keys.

## Validation commands

```sh
make check test
```

Or use the existing interpreter explicitly:

```sh
make check test PYTHON=.venv312/bin/python
```

This checks Django, migration consistency, Dart formatting/analyzer, backend tests
and Flutter tests. Backend tests use a test database. No test command seeds or
replaces the local demo database.

## Troubleshooting

| Symptom | Check / action |
| --- | --- |
| Flutter cache permission error in a restricted agent session | Allow the requested SDK access; do not change SDK ownership or upgrade it just to run the app. |
| Port already in use | Identify the existing listener; reuse it or choose another port. Stop only your own obsolete process. |
| Could not connect / CORS failure | Verify health endpoint, API address and CORS origin including port; use localhost consistently for web. |
| 127.0.0.1 on an Android emulator fails | Use 10.0.2.2 for the host machine's backend. |
| No device found | Use Chrome; native targets require separate SDK/emulator setup. A phone-shaped browser preview is not a native-device test. |
| Demo login rejects your password | Existing seeded accounts keep their original password; reseeding will not reset it. |
| Python packages missing | Activate the correct venv or pass `PYTHON=...`; run `make install-backend`. |
| Flutter SDK constraint failure | Check installed Dart against `mobile/pubspec.yaml`; use a compatible Flutter SDK. |
| Database tables missing | Run migrations with the same interpreter/environment used by the server. |
| Real email, payment or push does not work | Configure the provider described in APP_UPDATES.md; basic local mode does not provision services. |

## Onboarding acceptance

- [x] Current local interpreter/dependency versions checked.
- [x] Django configuration and migration consistency checked.
- [x] Existing backend/Flutter automated suites pass.
- [x] Local API health and data endpoints checked.
- [x] Prototype starts independently and supports the core review walkthrough.
- [ ] Repeat on a clean teammate machine.
- [ ] Run native smoke checks once a phone/emulator is available.
