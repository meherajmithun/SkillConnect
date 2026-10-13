# SkillConnect API

Base path: `/api/`. JSON requests and responses except portfolio image upload, which uses multipart form data. Authenticated endpoints use `Authorization: Bearer <access>`. Login accepts **email or username** in `username`, or email in `email`. Email matching ignores case and takes precedence if a username matches someone else's email. List responses are paginated as `{count, next, previous, results}` unless noted. Page size is 30; pass `page=2` for subsequent pages.

| Endpoint | Methods | Behavior |
| --- | --- | --- |
| `health/` | GET | Public service health and demo-payment mode |
| `auth/register/` | POST | Username, email, password, first/last name, phone, role (`customer` / `professional`) |
| `auth/login/` | POST | Email or username + password → access and refresh JWTs |
| `auth/refresh/` | POST | Refresh token → rotated tokens; old refresh is blacklisted |
| `auth/logout/` | POST | Refresh token → blacklist; existing access expires within 30 minutes |
| `me/` | GET, PATCH | Current account including read-only `email_verified`; changing email resets verification |
| `auth/password-reset/` | POST | Email → generic acknowledgement; send an eight-digit recovery code if account exists |
| `auth/password-reset/confirm/` | POST | Email, code and new_password → change password and revoke existing sessions |
| `auth/email-verification/` | POST | Authenticated user requests an email code |
| `auth/email-verification/confirm/` | POST | Authenticated user confirms their own email with code |
| `slots/` | GET, POST | Professional's own future slots; create with starts_at and ends_at |
| `slots/{id}/` | DELETE | Remove an owned slot with no booking history |
| `professionals/{id}/availability/` | GET | Public schedule_enabled and unreserved future slots; no customer details |
| `categories/` | GET | Public active categories; unpaginated |
| `areas/` | GET | Public areas and center coordinates; unpaginated |
| `professionals/` | GET | Public search with pagination and ranking |
| `professionals/{id}/` | GET | Business profile, skills, service areas, contact, portfolio and rating |
| `professionals/{id}/reviews/` | GET | Public visible reviews, paginated |
| `profile/` | GET, PATCH | Professional's own profile; verification is admin controlled |
| `portfolio/` | GET, POST | Professional's own projects; optional `image`, max 5 MB |
| `portfolio/{id}/` | GET, PUT, PATCH, DELETE | Owner-only project management |
| `bookings/` | GET, POST | Participant-only list; customer creates a service request |
| `bookings/{id}/` | GET | Participant-only booking detail |
| `bookings/{id}/status/` | POST | `{status: accepted/rejected/completed/cancelled}`; role and state enforced |
| `quotes/` | GET, POST | Participant-only list; customer requests an estimate |
| `quotes/{id}/` | GET | Participant-only quotation detail |
| `quotes/{id}/reply/` | POST | Requested professional replies with positive `amount` and `response` |
| `quotes/{id}/accept/` | POST | Customer supplies quote_revision, address, scheduled_at, duration_minutes and optional slot; creates one linked booking |
| `bookings/{id}/messages/`, `quotes/{id}/messages/` | GET, POST | Participant-only paginated conversations; send body |
| `bookings/{id}/messages/read/`, `quotes/{id}/messages/read/` | POST | Mark incoming messages through the supplied through_id as read |
| `reviews/` | POST | Customer reviews their own completed `booking`; `rating` 1–5 and `comment`; once per booking |
| `packages/` | GET | Public active promotion packages; unpaginated |
| `promotions/` | GET, POST | Professional's purchases; create with package, category and area IDs |
| `promotions/{id}/payment/` | POST, GET | Owner creates/resumes SSLCommerz checkout, or independently refreshes and validates its status |
| `payments/ipn/` | POST | Public provider callback with tran_id and val_id; verifies payment server-to-server |
| `payments/return/` | GET, POST | Informational browser return; never trusts posted payment status |
| `notifications/` | GET | Own notification inbox |
| `notifications/read-all/` | POST | Mark own inbox read |
| `reports/` | GET, POST | Own reports; create with professional ID and reason |
| `analytics/` | GET | Customer counts, professional business metrics, or staff system metrics |
| `devices/` | POST, DELETE | Register/remove authenticated user's native FCM token |

## Discovery filters

`category`, `area` (IDs), `q` (business/skills/bio search), `min_rating` (0–5), `available=true`, `lat`, `lng`, `max_distance` (km), `sort=recommended|rating|distance`, `page`.

Distance requires both coordinates. Unknown business locations are excluded when a distance limit is present and appear last in nearest sorting. Only active users with at least one active service category and one service area are discoverable. Sponsored visibility requires both a category and area filter; no promotion boost applies to unscoped browsing. A profile's approximate distance is included in search results; detail responses don't have a search origin.

## Booking request

```json
{
  "professional": 1,
  "category": 1,
  "area": 1,
  "scheduled_at": "2027-01-20T10:00:00+06:00",
  "address": "House 12, Mirpur, Dhaka",
  "details": "Repair a switchboard"
}
```

The professional must be active, available and serve the requested service and area. The schedule must be in the future. Customers can cancel pending/accepted bookings. Professionals accept/reject pending bookings and complete accepted bookings. Terminal states cannot be reversed. Both parties receive in-app updates.

Participant-only booking and quote responses include `customer_phone` and `professional_phone` for contacting the other party. These responses remain inaccessible to unrelated accounts.

Quotation requests use professional, category, area and details. Replies increment the quotation revision. Accept with `quote_revision`, `scheduled_at`, `duration_minutes` (default 60), `address` and optional `slot`. The backend snapshots the quotation price and terms and returns the resulting booking. Duplicate acceptance returns the same booking. Accepted estimates cannot be updated.

Bookings expose `quote`, `agreed_price`, `agreed_terms`, `duration_minutes` and `slot`. Pending and accepted bookings reserve time and cannot overlap. When `schedule_enabled` is true, new bookings must match an owned published slot's start and duration. Cancelled/rejected bookings release the time. Slots last 30–480 whole minutes and may be published within 90 days.

Email codes expire in 15 minutes, allow five failed attempts and are single-use. Requesting another code invalidates the prior code. Recovery endpoints use a separate IP throttle of 20 requests/hour. Email sending defaults to local console mode; set `EMAIL_MODE=smtp` to send actual messages.

## Profile update

Use `category_ids` and `area_ids` for writable many-to-many relations. `categories` and `areas` return expanded read-only objects. Coordinates must be a finite latitude/longitude pair or both null. `verified`, `rating`, `review_count`, `promoted` and contact name/phone cannot be written through the profile endpoint; update your account name/phone through `me/`.

## Access and errors

Public discovery is available without registration. Protected requests return 401 without valid JWTs. Participant-only resources return 404 to outsiders. Validation errors return 400 with field/message details. Authentication and recovery are limited to 20 requests/hour per IP. General API traffic is limited to 2000/hour per IP. Counters are stored in the database and shared across instances.

The JavaScript administration console is available at `/admin/`. It signs in through JWT authentication and calls staff-only `/api/admin/` endpoints. No public API can grant staff access. Administrator accounts are created through `npm run admin`.
