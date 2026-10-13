# SkillConnect 1.1.1 release validation

Checked on 2026-10-13 against the working tree before the release commit.

## Completed checks

| Check | Result |
| --- | --- |
| Backend tests | 41 passed (`.venv312/bin/python -m pytest -q`) |
| Django system and migration checks | Passed; no missing migrations |
| Flutter tests and analysis | 11 passed; no analysis issues |
| Dart formatting | Passed; no changes needed |
| Android release build | Passed with `ALLOW_HTTP=true` and emulator API URL `http://10.0.2.2:8000/api/` |
| APK upgrade metadata | Prior 1.1.0: `com.skillconnect.mobile`, version code 3. New 1.1.1: same package, version code 4. Both APKs use the same signing certificate (SHA-256 `88dccd5dcbea704f559839f2a39c4564c1f1f7d149c1c747bab28e4d6925acfb`). |

The new build is `mobile/build/app/outputs/flutter-apk/app-release.apk`. Its
SHA-256 is `ed4134c864a3189f3f575ce7e28ed7b83b1886d63fb0d8097e8b2dc25e08483e`.
That build uses the Android emulator API address and is not the LAN friends APK.
`dist/SkillConnect-friends-v1.1.1.apk` is an earlier local build; it was not
replaced or retested here.

## Device and user acceptance still required

No Android device was connected (`adb devices -l` was empty). The following
checks need a connected phone, a reachable backend, and a customer and
professional tester. Record device model, Android version, APK hash, backend
revision, tester, date, and pass/fail notes for each journey.

1. Install the 1.1.0 APK, sign in, create or locate a quote and booking, then
   install a 1.1.1 APK with the same signing certificate. Confirm the app opens,
   account data remains on the backend, and sign-in/session behavior is clear.
2. Customer: register, verify email, reset password, search/filter and compare,
   request a quote, accept an estimate into a booking, send messages, receive
   notifications, and review a completed booking.
3. Professional: edit profile and portfolio, publish availability, reply to a
   quote, message the customer, accept/complete a booking, and inspect analytics.
4. Staff: verify a professional, moderate a review, handle a report, and confirm
   a manual promotion payment. Check that an unpaid promotion never appears as
   sponsored and a paid promotion only boosts its chosen service and area.
5. Capture observed issues with reproduction steps, expected/actual behavior,
   severity, and the fix or accepted decision. Obtain customer, professional,
   and staff sign-off before distributing the APK.

## Provider checks still required if enabled

No local SSLCommerz merchant settings or Firebase build/service-account
configuration was present. Automated tests use mocked provider responses; they
do not prove live delivery. With authorized sandbox credentials and reachable
HTTPS callbacks, test successful, failed, cancelled, duplicate, and missed-IPN
promotion payments, including app reconciliation. With configured Firebase and
APNs as applicable, test foreground, background, and terminated-app delivery on
real devices, opt-in/out, retries, and invalid token removal. Keep live mode
disabled until these checks pass and the merchant owner approves it.
