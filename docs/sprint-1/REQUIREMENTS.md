# 1.1 Requirement analysis

## Problem and audience

Customers need a way to find local skilled service providers, compare evidence
of their work and agree on service requests. Professionals need a business
profile, a way to respond to work requests and control when/where they appear.
Staff need to manage catalog data, verification, moderation and promotions.

Sources: supplied WBS; root README; `docs/PROPOSAL_COVERAGE.md`, `docs/API.md`;
current models, serializers, endpoints and Flutter screens. This analysis does
not claim customer interviews or field research have taken place.

## Scope baseline

The MVP supports configurable service categories and areas, guest discovery,
customer/professional accounts, profiles/portfolio, quotations, bookings,
completed-service reviews, availability, paid area/category promotions and staff
administration. Dhaka areas and BDT are the current demonstration defaults.

Email recovery/verification, appointment slots, private messages and configurable
SSLCommerz checkout are existing extensions. Keep them in the inventory without
making provider provisioning a Sprint 1 dependency. In-app notifications work
independently of optional Firebase push.

Out of scope: payment escrow/refunds, route-based distance, live GPS tracking,
automated identity-document verification, public hosting provisioning and a
separate native staff app. A verified badge represents a staff decision, not an
automatic guarantee. A starting price is not an agreed final quotation.

## Functional requirements and traceability

Priority: **Must** = MVP requirement, **Should** = supporting capability,
**Extension** = implemented beyond the core WBS. Sprint refers to the WBS delivery
phase; implementation already present is not re-counted as Sprint 1 work.
Paths below are relative to the repository root. `screens/` means
`mobile/lib/screens/`; backend files mean `backend/src/`.

| ID | User need / priority | Testable acceptance criteria | WBS sprint | Existing evidence |
| --- | --- | --- | --- | --- |
| FR-01 | Browse without an account — Must | A guest can list active services/areas, search professionals and open public profiles; a protected action requires sign-in. | 2 | `marketplace.js`, `screens/discover.dart`, `test_authentication_required_for_mutations` |
| FR-02 | Register and sign in — Must | Customer/professional roles are selectable; invalid/weak input is rejected; registration cannot assign staff; login uses username; refresh/logout operate on tokens. | 2 | `auth.js`, `app.js`, `api.dart`, `screens/account.dart`, registration/JWT tests |
| FR-03 | Search and filter — Must | Category, area, text, rating and availability constrain results; rating/distance sorts work; no results and connection failure have recovery actions. Distances are from selected area center. | 2 | `marketplace.js`, `marketplace.js`, `screens/discover.dart`, distance/rating tests |
| FR-04 | Assess and compare professionals — Must | Show business name, bio, skills, experience, areas, starting price, portfolio and visible reviews; expose verification; compare 2–3 selected profiles. | 2 | `profile()` in `marketplace.js`, `ProfileScreen`, `CompareScreen` |
| FR-05 | Request and answer a quote — Must | A customer selects a served service/area and describes work; only the requested professional can reply with a positive amount; outsiders cannot read it. | 2 | `Quote`, quotation routes, `screens/activity.dart`, quote ownership tests |
| FR-06 | Maintain a business profile — Must | A professional edits only their own business/portfolio; images are validated; categories/areas are selectable; verification is not editable by the owner. | 2 | `Professional`, `Portfolio`, `screens/professional.dart`, ownership tests |
| FR-07 | Manage availability — Must | A professional can pause new requests; bookings to an unavailable professional fail; previously accepted work remains visible. | 2 | `Professional.available`, service-request validation, `BusinessScreen` |
| FR-08 | Book and track service — Must | A customer chooses a future appointment and address; professional accepts/rejects pending work, completes accepted work; customer can cancel pending/accepted work; terminal states cannot be reopened. | 3 | `Booking`, `marketplace.js`, `marketplace.js`, booking lifecycle/privacy tests |
| FR-09 | Review completed service — Must | Only the owning customer can submit a rating 1–5 once per completed booking; incomplete/foreign bookings are rejected; hidden reviews do not contribute to public ratings. | 3 | `Review`, review route, lifecycle/moderation tests |
| FR-10 | Promote by service and area — Must | Professional selects a package/category/area; purchase snapshots price/duration and waits for confirmed payment; only matching active promotions affect search; sponsored results are labeled and expiry is enforced. | 3 | `Promotion`, `PromotionPackage`, `marketplace.js`, `admin.js`, promotion tests |
| FR-11 | Administer marketplace — Must | Authorized staff can manage users/catalog/packages, verify professionals, moderate reviews and resolve reports; public APIs cannot elevate privilege. | 3 | `admin.js`, `marketplace.js`, role/permission tests |
| FR-12 | Receive updates and report issues — Must | Users see only their notifications/reports; booking/quote changes generate updates; a customer can report a professional; staff record resolution. | 3 | `Notification`, `Report`, notifications/reports tests |
| FR-13 | Inspect business performance — Should | Professional sees own work counts, rating and active promotions; staff metrics are restricted to staff. | 3 | analytics endpoint, `screens/account.dart`, `BusinessScreen` |
| FR-14 | Recover and verify account email — Extension | Expiring single-use codes; request response does not reveal account existence; successful password reset revokes existing sessions. | 3 | `auth.js`, `screens/recovery.dart`, recovery tests |
| FR-15 | Select appointments and accept estimates — Extension | Slots must be future/non-overlapping; accepting a quote snapshots its current price/terms and creates one booking; stale revisions fail. | 3 | `marketplace.js`, `screens/calendar.dart`, quote-acceptance/slot tests |
| FR-16 | Message about a request — Extension | Only participants can read/send; read receipts are scoped; empty message bodies fail. | 3 | `marketplace.js`, `screens/messages.dart`, conversation tests |
| FR-17 | Use optional external integrations — Extension | Native push requires device permission/configuration; payment is validated server-side before activation; browser return alone never activates payment. | 3–4 | `push.dart`, `payments.js`, `push-worker.js`, payment/push tests |

## Non-functional requirements

These are acceptance targets, not claims that every production property has been
certified. Existing automated checks are listed in [migration validation](../JAVASCRIPT_MIGRATION.md).

| ID | Requirement | Acceptance / measurement | Current evidence or gap |
| --- | --- | --- | --- |
| NFR-01 | Authorization and privacy | Reject foreign booking/quote/message access; hash passwords; prevent role/staff elevation; store JWTs in platform secure storage. | Backend permission tests and `api.dart`; production security review remains Sprint 4. |
| NFR-02 | Mobile usability | Main flows usable at 360 logical pixels and at 1000px; no clipped actions; errors explain recovery. | Existing Flutter layout tests; prototype checked at 360, 393 and desktop widths. |
| NFR-03 | Accessibility | Labeled inputs, visible keyboard focus, status text in addition to color, touch targets at least 44px; aim for WCAG AA text contrast. | Prototype specification; full assistive-technology audit remains Sprint 4. |
| NFR-04 | Data integrity | Invalid transitions, duplicate reviews, overlapping bookings and unpaid promotion activation are rejected by server rules. | Existing backend behavior tests; production concurrency/load validation remains open. |
| NFR-05 | Recoverable failure | Loading, no results, validation and offline states are actionable; retries do not silently duplicate accepted quotations/payments. | UI retry states, idempotency tests; prototype simulates errors without a backend. |
| NFR-06 | Reproducible development | Fresh environment can install dependencies, migrate, seed, run health endpoint and run tests using documented commands. | Existing environment checked; clean-machine install is not claimed. |
| NFR-07 | Performance | Proposed target: seeded local discovery API responds within 1 second over 20 warm requests; define larger dataset/device/network profile before production benchmarking. | Target only; not benchmarked in Sprint 1. |
| NFR-08 | Deployment configuration | Production uses PostgreSQL, HTTPS, secrets and restricted origins; integrations expose pending/failed states. | Config/scaffolding exists; no public deployment or provider certification claimed. |

## Data and access inventory

| Data | Writer | Reader / restrictions |
| --- | --- | --- |
| User credentials and tokens | Account owner / authentication service | Password hashes server-side; tokens private to client/session. Never include them in prototype data. |
| Professional and portfolio | Professional owner; staff controls verification | Public business information; edits restricted to owner/staff. |
| Category, area, package | Staff | Public active catalogs; package prices snapshot at purchase. |
| Booking, quote, message | Customer/professional according to workflow | Participants; staff booking monitoring through admin. Addresses are not public profile fields. |
| Review | Customer after completed booking; staff moderation | Public visible reviews; one per booking. |
| Promotion and payment | Professional initiates; staff/provider validates | Owner and staff; search exposes only applicable sponsorship status. |
| Notification, report, device | Recipient/reporter/device owner or server | Scoped to user; staff resolves reports. |

## Representative acceptance scenarios

- **Discovery:** Given Electrician and Mirpur filters, when the customer searches,
  show matching active profiles; a zero-result search offers reset/change filters.
- **Quote:** Given a guest on a profile, when they request a quote, require an
  account before creation. With an empty description, retain input and show the
  required-field error. A valid request appears in their private activity.
- **Booking:** Given a pending booking, only its professional may accept it.
  After completion, the owning customer can leave exactly one review.
- **Promotion:** Given an unpaid promotion, search must not boost it. After payment
  confirmation it may boost only matching category/area searches until expiry.
- **Professional:** Given an owner editing their business, saving affects only
  that profile; a request attempting to set `verified` cannot grant verification.

## Decisions and assumptions

| ID | Baseline decision / assumption | Confirmation owner |
| --- | --- | --- |
| A-01 | Retain Flutter + Node.js/Express and the existing blue/mint visual identity. | Product owner / technical lead |
| A-02 | Use Dhaka demonstration areas, BDT and English UI; Bangla localization is not currently implemented. | Product owner / customer representatives |
| A-03 | Staff use the JavaScript administration console; no mobile staff product is added by the prototype. | Operations owner |
| A-04 | Manual promotion-payment confirmation remains usable without gateway credentials. | Business / finance owner |
| A-05 | Team membership, actual sprint dates, interview participants and production service levels are unassigned. | Project lead |
| A-06 | Prototype improvements to sign-in continuation and compact discovery layout are proposals; current Flutter layout and navigation remain the implementation baseline. | Design / frontend owner |

Capture any approved change with its requirement ID, rationale, affected screens,
API/data impact, owner and target sprint in the backlog before implementation.
