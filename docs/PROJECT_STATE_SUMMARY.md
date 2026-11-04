# SkillConnect: Current State & Future Scope

Codebase review | 14 October 2026 | Flutter app v2.1.0+10

## Current project state

**Overall assessment:** SkillConnect is a functional marketplace MVP with customer, professional and staff workflows. Core business flows and automated checks are in place. Production readiness still depends on durable storage, configured external services and real-device acceptance testing.

**Architecture:** Flutter/Dart app → HTTP/JSON API → Node.js/Express → PostgreSQL (deployment) or SQLite (local development). A separate browser-based staff console uses the API; portfolio photos are stored on the server filesystem.

| Component | What exists today |
| --- | --- |
| Frontend | Flutter customer/provider screens: sign-up/login, saved-account suggestions, service/area/rating/distance filters, profile comparison, maps, portfolios, quotes, bookings, calendar, private messages, reviews, notifications and account recovery. Provider dashboard supports business setup, availability, promotions and basic metrics. Offline demo mode is separate from the live API. |
| Backend | Node.js 22+ / Express 5 modular REST API covers authentication, catalogue, marketplace, uploads, payments and administration. It enforces ownership, role permissions, booking transitions, overlapping-slot protection, quote revisions and one review per completed booking. Messaging currently polls every 15 seconds. |
| Database | Shared relational schema for PostgreSQL and SQLite, with foreign keys, unique/check constraints, a booking index and transactional writes. Records cover accounts, services/areas, profiles, portfolios, slots, quotes, bookings, reviews, promotions/payments, messages, notifications and sessions. Schema initialization, legacy import and catalogue setup exist. Photos are outside the database. |
| Security & administration | JWT access/refresh sessions, refresh rotation/revocation, scrypt password hashing, secure device storage, persisted rate limits and validated image uploads. Staff can activate accounts, verify professionals, moderate reviews/reports, manage reference data and confirm promotion payments. |
| Integrations & delivery | SMTP recovery/verification, Firebase push worker and SSLCommerz promotion checkout are implemented but require credentials and live validation. Manual payment confirmation and in-app notifications exist. Docker/PostgreSQL setup, Render deployment configuration, CI and Android APKs are present; release signing currently uses the debug key. |

### Verification from this review

- JavaScript syntax/format checks passed; backend tests: **44 passed on SQLite**.
- Dart formatting passed; Flutter analysis: **no issues**; Flutter tests: **30 passed, 3 live-build checks skipped**.
- CI is configured to test PostgreSQL and build APKs. PostgreSQL, hosted availability, physical devices and external provider delivery/transactions were **not revalidated in this review**.

<!-- PAGEBREAK -->

## Future scope and improvement priorities

### 1. Make deployment durable — highest priority

The Render configuration has no persistent media disk; uploads use local files. Add persistent storage or object storage, database/media backups and a tested restore process. Add health/error monitoring and a continuously managed push worker. Use a dedicated Android release key. This makes the existing product dependable for ongoing use.

### 2. Complete real integration and user acceptance testing

Configure SMTP, Firebase/APNs and SSLCommerz; verify recovery emails, background push, payment callbacks and payment reconciliation using real provider environments. Test customer-to-provider journeys on physical Android/iOS devices, including weak networks, permissions, keyboard/autofill and accessibility. iOS/web scaffolding alone does not establish release readiness.

### 3. Improve database evolution and performance

The schema records an initial migration version, but initialization relies on CREATE TABLE IF NOT EXISTS. Introduce ordered migrations for future column/constraint changes. Discovery loads profiles and performs repeated related queries before filtering and pagination; move filters/pagination into SQL, batch joins and add measured indexes. PostgreSQL currently serializes writes using one advisory lock; adopt narrower locking when load tests show contention.

### 4. Improve frontend and backend maintainability

Split the largest screens and marketplace module into smaller feature components/services. Define typed Flutter models and a documented API contract instead of spreading dynamic JSON maps. Add targeted device integration tests, loading/error/retry consistency, incremental list loading, accessibility checks and Bangla localization. Current list helpers can fetch every page, which will become expensive as data grows.

### 5. Expand the marketplace after the core is reliable

Add live location/geocoding and route distance, instant messaging updates instead of polling, reminders/rescheduling, broader service areas and richer provider analytics. Consider document-backed verification, disputes, refunds and service-payment/escrow workflows as separate product extensions. Existing checkout pays for promotions; escrow and service settlement are not implemented.

**Suggested sequence:** Durable hosting and backups → live integrations and device acceptance → migration/performance work → usability improvements → additional marketplace features.

### Evidence and scope

Reviewed active Flutter/API source, SQL schema, test suites, CI, deployment files and project documentation. Assessment reflects the current working tree; it is not a production security audit or a live-service certification.

Key sources: mobile/lib/; backend/src/{app,auth,marketplace,db,schema,uploads,payments,push-worker,admin}.js; mobile/android/app/build.gradle.kts; .github/workflows/ci.yml; compose.yaml; render.yaml; docs/PROPOSAL_COVERAGE.md; docs/ROLE_AUDIT_2_1_0.md.
