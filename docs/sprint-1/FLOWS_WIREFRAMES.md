# 1.4 User flows & wireframes

These flows describe the product baseline and the design proposal. Real app
navigation is in `mobile/lib/main.dart`; customer screens in `discover.dart`,
`activity.dart` and `account.dart`; professional screens in `professional.dart`.
The prototype focuses on discovery/quotation and profile/availability. Booking,
reviews, promotions and full administration are documented for later sprint
handoff rather than simulated as complete products.

## Information architecture

```text
SkillConnect
├── Discover (guest and signed-in)
│   ├── Service / area / text / rating / availability / distance filters
│   ├── Results → compare 2–3 profiles or map
│   └── Professional → portfolio / reviews / contact
│       ├── Request quote → authentication gate → request
│       └── Book service → authentication gate → appointment → request
├── Activity (signed-in)
│   ├── Bookings → status / messages / review after completion
│   ├── Quotes → reply (professional) / accept estimate (customer) / messages
│   └── Reports → resolution
├── My business (professional only)
│   ├── Edit business / portfolio
│   ├── Availability switch / appointment calendar
│   └── Promotions / business metrics
├── Account
│   ├── Guest → sign in / register / password recovery
│   └── Signed-in → account / email verification / notification permission / logout
└── Toolbar → server connection; notifications when signed-in

Separate staff surface: Node.js /admin/
└── Users / professionals / categories / areas / bookings / reviews /
    packages / promotions / reports
```

## Customer discovery and quote journey — FR-01–05

```mermaid
flowchart TD
  Start[Open Discover] --> Filter[Choose service and area]
  Filter --> Search{Search outcome}
  Search -->|Error| Retry[Explain connection failure and retry]
  Retry --> Filter
  Search -->|No matches| Empty[Change or clear filters]
  Empty --> Filter
  Search -->|Matches| Profile[Open professional profile]
  Profile --> Quote[Request quote]
  Quote --> Auth{Signed in as customer?}
  Auth -->|No| Login[Sign in or create customer account]
  Login --> Form[Choose service and area; describe work]
  Auth -->|Yes| Form
  Form --> Valid{Input valid?}
  Valid -->|No| Fix[Show field error; keep entered values]
  Fix --> Form
  Valid -->|Yes| Sent[Request created; awaiting reply]
  Sent --> Activity[Activity: Quotes]
  Activity --> Reply[Professional replies with price and terms]
  Reply --> Decide[Customer reviews estimate]
```

Design proposal: preserve the intended action after sign-in. The current Flutter
profile/auth path should be checked before porting this behavior. In the prototype
the sign-in gate is a demo action and does not collect a password or create users.

## Booking and review journey — FR-08–09, FR-15

```mermaid
flowchart TD
  Profile[Profile or answered quote] --> Slot[Choose future appointment]
  Slot --> Calendar{Published slots required?}
  Calendar -->|Yes| Pick[Pick an available published slot]
  Calendar -->|No| Time[Request a future time and duration]
  Pick --> Details[Address and work details]
  Time --> Details
  Details --> Check{Server validates availability and overlap}
  Check -->|Conflict| Retry[Explain conflict; choose another time]
  Retry --> Slot
  Check -->|Valid| Pending[Pending booking]
  Pending --> Decision{Professional decision}
  Decision -->|Accept| Accepted[Accepted]
  Decision -->|Reject| Rejected[Rejected]
  Pending --> Cancelled[Customer cancels]
  Accepted --> Cancelled
  Accepted --> Completed[Professional marks completed]
  Completed --> Review[Customer submits one rating and review]
```

Rejected, cancelled and completed are terminal booking states. A quotation is not
a confirmed appointment. Quote acceptance snapshots the current price/terms and
creates a pending booking; a changed quote must be reloaded before acceptance.

## Professional journey — FR-05–07

```mermaid
flowchart TD
  SignIn[Professional account] --> Business[My business]
  Business --> Edit[Edit business, skills, services and areas]
  Edit --> Validate{Valid fields?}
  Validate -->|No| Edit
  Validate -->|Yes| Save[Save own profile]
  Business --> Portfolio[Add portfolio title, description and optional image]
  Business --> Available[Pause or resume new requests]
  Business --> Calendar[Manage future appointment slots]
  SignIn --> Activity[Activity: Quotes and Bookings]
  Activity --> Quote[Open own quote request]
  Quote --> Reply[Send positive price and explanatory terms]
  Activity --> Booking[Accept or reject pending booking]
  Booking --> Complete[Complete accepted work]
```

Missing required fields keep the editor open. An unavailable professional should
not receive a new request. Pausing new requests does not erase existing work.
Verification remains a staff action. The prototype permits local profile edits,
availability changes and quotation replies; images/calendar are in the handoff.

## Staff and promotion process — FR-10–12

```mermaid
flowchart TD
  Staff[Staff signs in to the JavaScript administration console] --> Inspect[Inspect professional evidence]
  Inspect --> Verify[Verify or leave unverified]
  Staff --> Moderate[Review reports and moderate reviews]
  Pro[Professional chooses package, service and area] --> Pending[Pending payment]
  Pending --> Confirmation{Verified payment received?}
  Confirmation -->|No| Pending
  Confirmation -->|Yes| Activate[Activate once using purchase snapshot]
  Activate --> Match{Category and area match; not expired?}
  Match -->|Yes| Sponsored[Eligible for labeled sponsored ranking]
  Match -->|No| Normal[No promotion boost]
```

Staff sign-in, confirmation and verification are permission boundaries. The
prototype's Staff view is a labeled sample process screen, not the live administration UI.

## Low-fidelity mobile wireframes

Logical content width: 360–393px. Every screen scrolls above a persistent bottom
navigation bar. Actions remain reachable on small screens and with long content.

```text
DISCOVER                         RESULTS
┌───────────────────────────┐    ┌───────────────────────────┐
│ SkillConnect              │    │ ← Discover                │
│ A little help.             │    │ Electrician / Mirpur      │
│ Right around here.        │    │ Results count             │
│                           │    │ ┌───────────────────────┐ │
│ Service [Electrician   v] │    │ │ Name • verified       │ │
│ Area    [Mirpur        v] │    │ │ Skill / service area  │ │
│ Search  [             ]  │    │ │ Rating • starting BDT │ │
│ [Find professionals]      │    │ │ [View profile]        │ │
│                           │    │ └───────────────────────┘ │
│ Local professional sample │    │ [Change filters]          │
│ Discover Activity Account │    │ Discover Activity Account │
└───────────────────────────┘    └───────────────────────────┘

PROFILE                          REQUEST QUOTE
┌───────────────────────────┐    ┌───────────────────────────┐
│ ← Results                 │    │ ← Profile                 │
│ Professional name / badge │    │ Request a quote           │
│ Electrician / Mirpur      │    │ Professional name         │
│ Rating • experience       │    │ Service [              v] │
│ Starting price            │    │ Area    [              v] │
│ About / skills            │    │ Describe the work         │
│ Portfolio / review        │    │ [                       ] │
│ [Request quote]           │    │ [                       ] │
│                           │    │ Field error when needed   │
│ Discover Activity Account │    │ [Send quote request]      │
└───────────────────────────┘    └───────────────────────────┘

ACTIVITY                         MY BUSINESS
┌───────────────────────────┐    ┌───────────────────────────┐
│ Your quotes               │    │ Business name             │
│ ┌───────────────────────┐ │    │ Verification status       │
│ │ Request #Q001         │ │    │ [Available for requests]  │
│ │ Professional / work   │ │    │ [Edit business profile]   │
│ │ Status: awaiting reply│ │    │                           │
│ │ or price + terms      │ │    │ Services / areas / skills │
│ └───────────────────────┘ │    │ Starting price            │
│ Empty → Find professional │    │ Portfolio sample          │
│ Pro → Reply amount/terms  │    │ [Open quote requests]     │
│ Discover Activity Account │    │ Activity Business Account │
└───────────────────────────┘    └───────────────────────────┘
```

The interactive prototype offers the same screens in **Wireframe** mode. The
following screens are handoff wireframes for later sprint work, not clickable
features in the Sprint 1 prototype:

```text
BOOKING                          REVIEW / PROMOTION
┌───────────────────────────┐    ┌───────────────────────────┐
│ Book service              │    │ Review completed booking  │
│ Professional / service    │    │ Rating [1 2 3 4 5]        │
│ [Choose date & time]      │    │ Comment [               ] │
│ Address [               ] │    │ [Publish review]          │
│ Work    [               ] │    ├───────────────────────────┤
│ Price / accepted terms    │    │ Promote your business     │
│ [Request booking]         │    │ Service / area            │
│                           │    │ Package / duration / BDT  │
│ Pending → Accepted        │    │ [Confirm purchase]        │
│ → Completed → Review      │    │ Pending payment / Active  │
└───────────────────────────┘    └───────────────────────────┘
```

## State inventory

| Surface | Loading | Empty | Error | Success |
| --- | --- | --- | --- | --- |
| Discovery/results | Progress with status label | No matches; change filters | Could not connect; retry | Count + profiles |
| Profile | Progress | No portfolio/reviews yet | Retry or return to results | Evidence + request action |
| Quote form | Sending; prevent duplicate action | Required description | Field-specific correction | Request in Activity |
| Activity | Progress | No quote requests; find professional | Retry | Awaiting reply / answered amount and terms |
| Business edit | Loading/saving | Required fields prompted | Keep values; explain validation | Saved message and updated profile |
| Availability | Saving | N/A | Restore previous state if server save fails | Available / paused label |
| Staff verification | Saving | No pending records | Explain failed action | Updated badge and decision feedback |

Prototype state controls simulate loading, empty and offline results. Server-side
errors and save failures remain acceptance scenarios for the real app.
