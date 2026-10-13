# App updates · version 1.1.2

## View the layout without a server

Version 1.1.2, build 5, keeps the Discover banner, search layout and navigation
visible while connecting or when the server is unavailable. A connection card
explains that services, areas and professionals need a server. Data-dependent
filters are disabled until connection succeeds. **Try again** restores live
discovery when the backend becomes reachable. This does not add offline accounts,
bookings or sample professional listings.

Install `dist/SkillConnect-friends-v1.1.2.apk` over the previous friends build.
Flutter analysis and all 11 widget tests passed, including a 360 px offline
layout and successful reconnection test. Physical-device verification remains
pending.

These updates run with the existing local backend. No hosting is provisioned.

## Update a local installation

Activate the Python 3.12 environment, then:

```sh
python backend/manage.py migrate
python backend/manage.py runserver 0.0.0.0:8000
```

Allow your Wi-Fi IP in `ALLOWED_HOSTS`, as described in `ANDROID_SHARING.md`.
Install `dist/SkillConnect-friends-v1.1.2.apk` over the previous friends build.
Existing accounts and data are preserved. The icon update was introduced in version 1.1.1, build 4; see `BRANDING.md`.

## Account recovery and email verification

- Sign in → **Forgot password?** → enter your email → enter the emailed code
  and a new password.
- Account → **Verify your email** → send a code → enter it.
- Codes expire after 15 minutes, are stored as password hashes, work once,
  and lock after five incorrect attempts. Resending invalidates the earlier code.
- Password reset invalidates existing access and refresh sessions. Changing
  email clears email verification and invalidates old email challenges.
- Email verification confirms email ownership. The public professional badge
  remains administrator-controlled.

Local development prints email messages, including the code, in the backend
terminal. The API never returns codes. To send real email, export the email
variables from `.env.example`, choose
`django.core.mail.backends.smtp.EmailBackend`, and supply your SMTP service's
host, credentials and authorized sender. Python commands do not load `.env`
automatically; export variables before starting the process. Docker Compose
passes the configured variables through.

## Quotation bookings

Customers can use **Accept estimate and book** from Activity → Quotes. The
service, area, description, price and included work carry into the booking.
Choose an appointment and provide the service address. The booking still
requires professional acceptance.

The backend rejects stale quotation revisions. Accepted prices and terms are
snapshots, and accepted quotations cannot be edited. Repeating acceptance
returns the same booking. A cancelled quotation booking remains linked to its
original estimate; request a new estimate to start a separate booking.

## Availability calendar

My business → **Manage availability calendar** → publish appointments within
the next 90 days, each lasting 30–480 minutes. Enable **Require a published
appointment** to restrict new bookings to these slots.

Customers select a slot during booking. When calendar restrictions are off,
they can also request another time and duration. Pending and accepted bookings
reserve the entire appointment; overlapping requests are rejected. Cancellation
or rejection releases the time. Slots with booking history cannot be deleted.
Appointment times are displayed in the device's local time and stored as
time-zone-aware timestamps.

## Messaging

Activity → a booking or quotation → **Messages**. Both participants can send
messages of up to 2,000 characters and see read receipts. Conversations are
private to the request participants. New messages generate in-app notifications
and, when enabled, queued push notifications.

The screen checks for updates every 15 seconds while open and active. Refresh
and older-message pagination are available. It pauses polling when the app is
in the background. Messages on a quotation remain in that quotation's
conversation after acceptance; the resulting booking has its own conversation.

## Native push notifications

1. Register `com.skillconnect.mobile` in your Firebase project for the target
   platform. Follow [Firebase's setup guide](https://firebase.google.com/docs/flutter/setup).
2. Copy `.firebase-build.example.json` to `.firebase-build.json`. Set
   `FIREBASE_ENABLED` to `true` and fill the API key, project ID, sender ID and
   platform app ID from your Firebase app settings. These values initialize
   Firebase explicitly; the backend service-account key must never go into the
   APK. Without these settings, builds retain working in-app notifications.
3. Build from `mobile/` with
   `--dart-define-from-file=../.firebase-build.json` in addition to the API URL
   and local HTTP flags. For iOS, enable Push Notifications and Remote
   Notifications capabilities in Xcode, use an appropriate provisioning profile,
   and upload your APNs authentication key to Firebase.
4. Set `FIREBASE_CREDENTIALS` to your backend service-account JSON path and run:

   ```sh
   python backend/manage.py deliver_push --watch --interval 30
   ```

5. Sign in and tap Account → **Enable device notifications**. Registration
   restores on subsequent sign-ins after opt-in. Foreground messages display
   an app banner; tapping background notifications opens Notifications.

Run one worker. It tracks delivery per device, backs off failed sends and
removes unregistered tokens. Delivery remains at least once: a process failure
between provider acknowledgement and database update can cause a duplicate.
For Docker, put the key in ignored `backend/credentials/`, set the container
path in `.env`, and run `docker compose --profile push up --build -d`. The
worker waits for the API health check before starting.

Real-device Android/iOS delivery requires your Firebase/APNs configuration and
cannot be verified using empty template credentials. The local friends APK
does not enable Firebase until rebuilt with your configuration.

## Promotion payments

The integration uses [SSLCommerz hosted checkout](https://developer.sslcommerz.com/doc/v4/).
Merchant credentials stay on the backend. Configure `SSLCOMMERZ_STORE_ID`,
`SSLCOMMERZ_STORE_PASSWORD`, `SSLCOMMERZ_SANDBOX` and
`PAYMENT_CALLBACK_BASE_URL` (the backend origin without `/api/`). Leave
credentials empty to retain manual administrator payment confirmation.

When configured, Promotions offers checkout and **Refresh payment status**.
Sandbox checkout is explicitly labeled. The app opens the provider's hosted
page; it does not collect card information. Only independently validated
transaction IDs, validation IDs, BDT amounts and successful provider statuses
can activate a promotion. Risky payments require administrator review.
Unresolved checkout attempts must be reconciled before another attempt;
reopening pending checkout reuses the same payment session.

The IPN endpoint is `/api/payments/ipn/`; browser return is
`/api/payments/return/`. Browser redirects alone do not mark payments paid.
The owner can refresh a payment from the app, which queries and validates the
provider even if an IPN was missed. Live operation needs merchant credentials
and reachable HTTPS callbacks. This work supplies the integration without
setting up hosting or claiming that live payments are activated. Sandbox
validation and callbacks must be tested with your own merchant account before
switching to live mode. Refunds and service-booking payments are outside this
promotion-payment integration.

## Validation

```sh
python -m pytest -q
make check-backend
make check-mobile test-mobile
```

Automated tests use mocked email, Firebase and payment transports; they cover
expiry/replay/session revocation, scheduling, quotation price snapshots,
messaging isolation and receipts, payment tampering/reconciliation, and push
retry behavior. Provider credentials and real delivery require separate checks.
