# SkillConnect

**Find skills. Connect locally. Grow your business.**

A local service marketplace built from [the project proposal](SkillConnect_2_Page_Proposal_Python.pdf). Customers discover and compare professionals, request quotations, book services and review completed work. Professionals manage a digital business profile, receive requests and purchase service/area-specific promotions.

The version 1.1.0 update adds email recovery/verification, appointment scheduling, accepted-quotation bookings, private messaging and configurable SSLCommerz checkout. Version 1.1.2 keeps the Discover layout visible without a backend connection. See [app updates and integration setup](docs/APP_UPDATES.md).

Version 1.2.0 adds an interactive offline demo for faculty review. Install
`dist/SkillConnect-demo-v1.2.0.apk` to explore customer and professional journeys
with sample data saved on the phone. See the [faculty walkthrough](docs/FACULTY_DEMO.md).

## Stack

- Flutter/Dart app for Android, iOS and web.
- Python 3.12+, Django 5.2 LTS, Django REST Framework and JWT authentication.
- PostgreSQL for deployment; SQLite for quick local development.
- OpenStreetMap discovery maps; optional native Firebase Cloud Messaging.
- Django admin for users, categories, verification, review moderation, promotion pricing and reports.

See [project structure](docs/PROJECT_STRUCTURE.md) for the directory layout and module responsibilities. Run `make help` for common development commands after installing the dependencies below.

## Sprint 1 — Planning & UI/UX

The [Sprint 1 package](docs/sprint-1/README.md) covers all six Week 1–2 WBS items:
requirements, project planning, stakeholders, user flows/wireframes, UI design and
development setup. It includes code traceability and an interactive phone
prototype with customer/professional journeys and a wireframe mode.

Run `make prototype` and open **http://localhost:8082** beside your editor. The
prototype uses sample data and runs independently of the actual Flutter app.
See the [setup guide](docs/sprint-1/SETUP.md) for first-time installation and checks.

## Run the backend

```sh
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements-dev.txt
python backend/manage.py migrate
export DEMO_PASSWORD='choose-your-own-demo-password'
python backend/manage.py seed_demo
python backend/manage.py createsuperuser
python backend/manage.py runserver 0.0.0.0:8000
```

API: `http://localhost:8000/api/` · Admin: `http://localhost:8000/admin/`

Seeded accounts: `customer` (customer), `rahim` (electrician), `sadia`, `karim`, `farzana`, `imran`, and `tanim` (professionals). All use the password you supply in `DEMO_PASSWORD`. Seeding is repeatable and does not overwrite existing accounts or packages. Demo phone numbers and portfolio entries are illustrative, not real service providers.

## Run Flutter

Install a recent stable Flutter SDK with Dart **3.13.2 or later**, then:

```sh
cd mobile
flutter pub get
# Android emulator:
flutter run --dart-define=ALLOW_HTTP=true --dart-define=API_URL=http://10.0.2.2:8000/api/
# Browser (fixed port matches the default CORS configuration):
flutter run -d chrome --web-port=8080 --dart-define=ALLOW_HTTP=true
```

Use the link icon in the app toolbar to change the server address. The app tests the connection before saving it and signs out when switching servers. JWT tokens are stored using platform secure storage and refreshed automatically. On web, use HTTPS or localhost for the browser's secure storage requirements.

## Share the APK

See [Android sharing instructions](docs/ANDROID_SHARING.md). The friends build supports HTTP for local Wi-Fi testing and is signed with the development key. It requires the Python backend; the APK does not contain a database server or a public hosting service.

```sh
cd mobile
flutter build apk --release \
  --dart-define=ALLOW_HTTP=true \
  --dart-define=API_URL=http://YOUR_COMPUTER_IP:8000/api/
```

Output: `mobile/build/app/outputs/flutter-apk/app-release.apk`. GitHub Actions also builds and uploads an APK artifact on each push.

## PostgreSQL with Docker

```sh
cp .env.example .env
# Edit .env with a random SECRET_KEY, strong POSTGRES_PASSWORD and allowed hosts.
docker compose up --build -d
docker compose exec api python manage.py createsuperuser
docker compose exec -e DEMO_PASSWORD='choose-your-own-demo-password' api python manage.py seed_demo
```

Compose defaults to a local development deployment. For production, set `DEBUG=false`, use PostgreSQL, set exact host/origin allowlists and put an HTTPS reverse proxy in front of Gunicorn. Forward `X-Forwarded-Proto` only from a trusted proxy. WhiteNoise serves collected admin static files. Serve `/media/` from the mounted media volume through the proxy or use object storage; Django only serves uploads in debug mode. Back up both PostgreSQL and uploaded media.

For a native production build, use an HTTPS `API_URL`, omit `ALLOW_HTTP=true`, and configure your own Android signing key instead of the template development key. Do not expose the Django development server publicly.

## Promotions and payments

The four proposal packages are seeded at BDT 100 / 1 day, 300 / 7 days, 500 / 15 days and 800 / 30 days. Administrators can edit prices, durations and availability. A purchase snapshots the price and duration so later package edits cannot change an existing order.

Purchases remain **pending payment**. Collect and verify payment outside the app, then use **Confirm received payment and activate promotions** in Django admin. Optional SSLCommerz hosted checkout provides server-validated promotion payments when merchant credentials are configured. The app does not collect card details. See [payment setup](docs/APP_UPDATES.md#promotion-payments). Confirming twice cannot extend a promotion. A development-only `DEMO_PAYMENTS=true` setting activates simulated purchases immediately; the app explicitly labels this mode, and production disables it.

Sponsored results only apply when both the searched category and area match an active, paid promotion. Expiry is evaluated at search time. Recommended ranking uses rating + profile quality + a bounded promotion boost − distance penalty. Highest-rated and nearest sorting remain available. Sponsored cards are labeled. Distance is measured from the chosen area's center to a professional's business coordinates, not route distance or live GPS.

## Firebase notifications

Booking, quotation and promotion updates are always available in the app's Notifications page. Native push is optional:

See [native push setup](docs/APP_UPDATES.md#native-push-notifications) for Firebase build configuration, APNs requirements and the local/Docker worker. Enable notifications in Account after building with your configuration. The worker tracks each device separately, retries failed sends and removes invalid tokens. In-app notifications work without Firebase credentials.

## Validate

```sh
pytest -q
python backend/manage.py check
python backend/manage.py makemigrations --check --dry-run
cd mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Tests cover permissions, JWT rotation/logout, service requests, booking transitions, completed-booking reviews, moderation, promotion scope/expiry/price snapshots, ownership, ranking and mobile layouts. CI runs backend tests against PostgreSQL and produces the Android APK. iOS signing and credential-dependent push/payment integrations require separate deployment configuration.

See [API reference](docs/API.md) and [proposal coverage](docs/PROPOSAL_COVERAGE.md).
