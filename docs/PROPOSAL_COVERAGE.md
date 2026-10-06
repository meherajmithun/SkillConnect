# Proposal implementation

Source: `SkillConnect_2_Page_Proposal_Python.pdf`.

| Proposal requirement | Implementation |
| --- | --- |
| Flutter/Dart mobile frontend | Android/iOS scaffolding and responsive Flutter screens; web preview |
| Python Django/FastAPI backend | Django REST Framework API; Django selected from the proposed options |
| PostgreSQL | Environment-configured PostgreSQL, Docker Compose, PostgreSQL CI tests; SQLite local fallback |
| JWT authentication | Registration, role separation, access/refresh tokens, rotation, logout blacklist, secure mobile storage |
| Service and area search | Seeded physical/digital service categories and Dhaka areas, text search, filters |
| Rating and distance filters | Visible-review averages, coordinate distance calculation, sorting and distance limits |
| Compare professional profiles | Side-by-side comparison of up to three profiles |
| Business profile and direct contact | Bio, skills, experience, service areas, starting price, verification, phone link |
| Portfolio | Project descriptions and validated image uploads, owner-only management |
| Request quotations | Customer requests, professional price/response, private quote tracking |
| Booking and tracking | Future scheduling, pending/accepted/rejected/completed/cancelled lifecycle and participant authorization |
| Rating and reviews | One review per owned completed booking; admin visibility moderation affects ratings |
| Availability | Professional can pause new bookings/quote requests |
| Area-based timed promotion | Category/area matching, automatic expiry, labeled sponsored cards, bounded quality-aware boost |
| Four promotion packages | Configurable starter/weekly/half-month/monthly prices and durations from PDF |
| Promotion purchase | Pending purchase and manual verified-payment activation; explicit development-only simulated checkout |
| Professional analytics | Booking, completed, pending and quote counts, rating and active promotions |
| Admin user/category management | Django admin role-aware users, account activation, categories and areas |
| Professional verification | Staff verify/unverify actions and public badge |
| Booking monitoring | Read-only administrative booking detail and status filters |
| Review moderation | Hide/restore actions; hidden reviews excluded from public rating/search |
| Pricing and promotion control | Editable packages; snapshot pricing; confirm payment/cancel actions |
| System analytics and reports | Staff metrics API/account dashboard, customer reports, admin resolution tracking |
| Mapping | OpenStreetMap business pins and contributor attribution |
| Firebase Cloud Messaging | Device registration, permission UI, queued push worker; native Firebase/APNs configuration required |

## Scope boundaries

This repository supplies a working local marketplace and deployment scaffolding. It does not provision public hosting, a payment merchant account, Firebase credentials, APNs credentials or production signing keys. No real payment gateway is claimed: administrators verify externally received payments. Push delivery needs the documented native Firebase setup and a scheduled worker. In-app notifications work without those credentials.

The proposal does not specify route-based distance, live GPS, chat, identity-document upload, payment escrow or refunds; those are not implemented. Professional verification is a staff decision. The admin console is browser-based; customers and professionals use the Flutter app. Services and areas are configurable in admin rather than tied to external geocoding.
