# Customer and service provider audit — 2.1.0

Audited on 14 October 2026 against the Node API, Flutter app and hosted public
catalogue. The original hosted `/api/categories/` and `/api/areas/` both returned
empty lists, preventing real providers from configuring a usable business.

## Verified gaps and fixes

| Finding | Result |
| --- | --- |
| Empty hosted reference tables | A transaction initializes eight service categories, three existing Dhaka areas and four promotion packages once. Existing catalogue tables, later administrator edits and deletions are preserved. No example accounts, profiles, requests or reviews are created. |
| Provider setup is easy to miss | Live providers start in My business. An explicit setup action opens service and area selection; selected services and areas are visible in the dashboard. |
| Incomplete businesses appear in search | Discovery requires at least one active service and area. Providers retain access to their own profile while configuring it. |
| Email cannot be used to sign in | Both roles can sign in by email, case-insensitively, or username. Canonical email takes precedence over a colliding username. |
| Missing saved-password flow | Saving is opt-in after successful authentication. Encrypted device storage holds up to eight accounts per API address. Tapping an account fills its email and password; forgetting removes its app suggestion. Failed sign-ins and demo accounts are not saved. |
| Autofill hints without a complete lifecycle | Related fields share an AutofillGroup. Successful opted-in authentication commits the native autofill context; leaving or switching forms cancels it. Registration includes password confirmation. |
| Stale saved accounts after account changes | Account edits update saved email/username. Password recovery removes the old saved credential; a reset affecting the current account also clears its session. |
| Portfolio cannot be edited in the app | Tap a project to edit title/description and optionally replace its photo. PATCH preserves an existing photo when no replacement is selected. Demo edits update the existing project. |
| Quote area and useful booking contact are absent | Quote cards show service area. Participant-only responses expose contact numbers; booking cards provide a call action. Review and estimate labels match the viewing role. |
| Removed service/area crashes quote acceptance | The request screen explains that the estimate needs updating rather than constructing a dropdown with an invalid selection. Backend validation still enforces provider offerings. |
| Some lists silently stop at 30 records | The list helper retrieves every page from the configured API, ignoring server-supplied URL origins. This covers notifications, reviews and promotions. |
| A temporary outage deletes a session | Startup preserves tokens on connection/server failures and clears rejected sessions. Account offers a retry action. |
| Android backup can restore unusable encryption keys | Automatic app backup is disabled in the manifest, following the secure-storage package guidance. |

## Role coverage

| Flow | Customer | Service provider | Evidence |
| --- | --- | --- | --- |
| Register, login, profile edits, saved passwords, logout | Own account | Own account | API permissions and Flutter auth/credential tests |
| Discovery, filters, comparison, public profile, map and reviews | Browse and compare | Browse; own business preview | Existing public-response tests and phone/desktop widget tests |
| Business services, areas, availability and verification | Read selected offerings | Update own profile; verification stays staff-controlled | New provider onboarding and multi-area tests; existing ownership tests |
| Portfolio and image validation | View work | Add, edit, delete own projects | Upload/ownership tests plus new edit and demo tests |
| Published calendar | Choose available times | Publish slots, require calendar, remove unused slots | Existing overlap, ownership, duration and booking-history tests |
| Bookings | Create, track, cancel, message and review completed work | Accept/reject, complete, message and see customer review | HTTP lifecycle/privacy/concurrency tests and offline role journey |
| Quotes | Request, message and accept a current estimate | Respond/update before acceptance | Revision, snapshot, replay, role and stale-service tests |
| Promotions | See sponsored listings within matching service/area | Select package, request purchase, track activation/expiry | Existing purchase, tampering, payment and ranking tests |
| Notifications and analytics | Own updates and counts | Own updates and business metrics | Scoped API tests and pagination regression |
| Reports and moderation | Submit and track own reports | Access only own reports; staff controls moderation | Existing scoping and administration tests |
| Recovery and email verification | Own email | Own email | Existing expiry, attempts, resend and session-revocation tests; mocked delivery |

## Validation

- JavaScript syntax and formatting checks passed.
- Backend: 44 tests passed on SQLite and on isolated PostgreSQL.
- Flutter analysis: no issues. Default suite: 30 passed, three live-only checks
  skipped. Tests at 360 px and 1000 px cover layout and interactions.
- Live settings: 16 selected tests passed, one demo-only test skipped, with
  `DEMO_AVAILABLE=false` and the hosted HTTPS API URL.
- Release APK built as version 2.1.0, build 10, using the same development signing
  configuration as the previous APK. Live mode excludes demo controls/data.
- No physical Android device or emulator was available. Native keyboard/password
  manager presentation and real phone installation still need device verification.

The APK is `dist/SkillConnect-v2.1.0.apk`; generated binaries stay outside Git
history. GitHub Actions publishes its live APK artifact for the commit.

## External integration limits

Email delivery requires SMTP credentials; this audit verifies its API behavior
with a mocked transport. Native push requires Firebase configuration and a
worker; the live APK currently uses in-app notifications. Online payments require
SSLCommerz merchant settings; manual administrator confirmation remains available.
Those external providers were not provisioned or tested with real transactions.
The free Render filesystem is ephemeral, so uploaded photos can disappear after
a restart or redeploy; persistent hosting/storage remains a deployment decision.

The initial service area catalogue is Mirpur, Dhanmondi and Uttara. Administrators
can add other supported areas; providers choose their coverage from that catalogue.

Autofill presentation depends on the configured device password manager. App
suggestions work independently. Forgetting an app suggestion does not remove an
entry separately saved by the system password manager.

Implementation references: [Flutter autofill lifecycle](https://api.flutter.dev/flutter/widgets/AutofillGroup-class.html),
[secure storage and Android backup](https://pub.dev/packages/flutter_secure_storage).
