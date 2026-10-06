# SkillConnect API

Base path: `/api/`. JSON requests and responses except portfolio image upload, which uses multipart form data. Authenticated endpoints use `Authorization: Bearer <access>`. Login uses **username**, not email. List responses are paginated as `{count, next, previous, results}` unless noted. Page size is 30; pass `page=2` for subsequent pages.

| Endpoint | Methods | Behavior |
| --- | --- | --- |
| `health/` | GET | Public service health and demo-payment mode |
| `auth/register/` | POST | Username, email, password, first/last name, phone, role (`customer` / `professional`) |
| `auth/login/` | POST | Username + password → access and refresh JWTs |
| `auth/refresh/` | POST | Refresh token → rotated tokens; old refresh is blacklisted |
| `auth/logout/` | POST | Refresh token → blacklist; existing access expires within 30 minutes |
| `me/` | GET, PATCH | Current account; role, username and staff status cannot be changed here |
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
| `reviews/` | POST | Customer reviews their own completed `booking`; `rating` 1–5 and `comment`; once per booking |
| `packages/` | GET | Public active promotion packages; unpaginated |
| `promotions/` | GET, POST | Professional's purchases; create with package, category and area IDs |
| `notifications/` | GET | Own notification inbox |
| `notifications/read-all/` | POST | Mark own inbox read |
| `reports/` | GET, POST | Own reports; create with professional ID and reason |
| `analytics/` | GET | Customer counts, professional business metrics, or staff system metrics |
| `devices/` | POST, DELETE | Register/remove authenticated user's native FCM token |

## Discovery filters

`category`, `area` (IDs), `q` (business/skills/bio search), `min_rating` (0–5), `available=true`, `lat`, `lng`, `max_distance` (km), `sort=recommended|rating|distance`, `page`.

Distance requires both coordinates. Unknown business locations are excluded when a distance limit is present and appear last in nearest sorting. Only active users are discoverable. Sponsored visibility requires both a category and area filter; no promotion boost applies to unscoped browsing. A profile's approximate distance is included in search results; detail responses don't have a search origin.

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

Quotation requests use professional, category, area and details. A replied quote is an estimate; the customer creates a separate booking, and should include agreed terms in its details.

## Profile update

Use `category_ids` and `area_ids` for writable many-to-many relations. `categories` and `areas` return expanded read-only objects. Coordinates must be a finite latitude/longitude pair or both null. `verified`, `rating`, `review_count`, `promoted` and contact name/phone cannot be written through the profile endpoint; update your account name/phone through `me/`.

## Access and errors

Public discovery is available without registration. Protected requests return 401 without valid JWTs. Participant-only resources return 404 to outsiders. Validation errors return 400 with field/message details. Authentication is limited to 20 anonymous requests per hour; public anonymous traffic is limited to 120/hour and users to 2000/hour. Configure a shared cache and edge rate limiting for a multi-worker production deployment.

Administrative actions use Django's session-authenticated, CSRF-protected `/admin/` interface. No public API can grant staff access, verify professionals, alter pricing, confirm payment or resolve reports.
