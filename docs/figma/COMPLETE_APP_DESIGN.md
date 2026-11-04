# SkillConnect — Complete app design

Created 24 October 2026 from the current SkillConnect project and the supplied
EduShare visual reference.

- [Open the complete Figma design](https://www.figma.com/design/Bjbp7d5JP6ejxWGytCtywX?node-id=13-2)
- [Customer prototype](https://www.figma.com/proto/Bjbp7d5JP6ejxWGytCtywX?node-id=6-319&starting-point-node-id=6%3A319)
- [Professional prototype](https://www.figma.com/proto/Bjbp7d5JP6ejxWGytCtywX?node-id=7-595&starting-point-node-id=7%3A595)
- [Staff prototype](https://www.figma.com/proto/Bjbp7d5JP6ejxWGytCtywX?node-id=9-33&starting-point-node-id=9%3A33)
- [Welcome and authentication](https://www.figma.com/proto/Bjbp7d5JP6ejxWGytCtywX?node-id=6-14&starting-point-node-id=6%3A14)
- [Visual reference: EduShare](https://www.figma.com/design/DtND6WxttAlYAZAe6t9WGF?node-id=1-2588)

## Deliverable

98 product screens and state examples, organized across five pages. Mobile
screens are 393 × 852; staff desktop screens are 1440 × 960. The overview contains
editable app previews and buttons that open each role's prototype.

| Page | Contents |
| --- | --- |
| 00 · Start here | Overview, prototype launch links and file guide |
| 01 · Design system | Shared tokens, Inter typography, reusable components and state variants |
| 02 · Mobile app & prototype | 9 authentication, 35 customer and 24 professional screens |
| 03 · Staff console | 22 desktop screens covering all ten staff resource areas |
| 04 · States & handoff | 8 state examples, product rules and implementation guidance |

### Screen coverage

| Area | Included screens |
| --- | --- |
| Authentication (9) | Welcome; customer and professional sign-in; customer and professional registration; password recovery; reset code; new password; reset success |
| Customer discovery (12) | Discover; results; filters; map preview; comparison; professional profile; portfolio; reviews; public contact; quote request; quote sent; email verification |
| Customer requests (10) | Quotes; received estimate; published appointment selection; custom appointment; booking form; pending booking; bookings; booking detail; completed work; review form |
| Customer account/support (13) | Review success; inbox; conversation; notifications; account; account editor; notification settings; notification permission; report form; report confirmation; reports; connection settings; cancellation confirmation |
| Professional business (24) | Business dashboard; profile editor; portfolio; add project; quotation requests; request detail; estimate reply; bookings; pending booking detail; accepted booking; rejection confirmation; completion confirmation; calendar; publish slot; availability settings; paused state; promotion packages; checkout; pending payment; active promotion; analytics; account; private conversation; notifications |
| Staff (22) | Sign-in; dashboard; users; user detail; professionals; verification review; services; areas; bookings; booking detail; quotes; quote detail; reviews; moderation detail; promotions; payment confirmation; packages; reports; report resolution; package editor; category editor; area editor |
| States (8) | Loading; empty search; connection error; form validation; unavailable professional; appointment conflict; authentication gate; expired promotion |

## Visual system

The requested EduShare direction supplies dark navy surfaces, electric blue
actions, rounded cards, compact utility text and Inter typography. The original
SkillConnect S-link logo remains the brand mark. Mint, amber and red communicate
verification, pending decisions and problems.

- 30 reusable main components, including the staff table row.
- Five variant families: primary button, input, badge, customer navigation and
  professional navigation.
- Three variable collections with 52 variables: primitives, semantic dark colors,
  and spacing/radii. Semantic colors alias primitives; variables have explicit
  scopes and web code syntax.
- 75 Inter text styles. Main screens and previews use Inter throughout.
- Mobile content scrolls above fixed bottom navigation.

## Prototype behaviour

Five named main flows cover welcome/authentication, the customer journey,
professional business management, staff sign-in and staff administration.
There are 316 mobile and 297 staff navigation links. All 68 mobile screens are
reachable from Welcome; all 22 staff screens are reachable from the dashboard.
The state examples have a separate illustrative replay flow.

This is a Figma design prototype with predetermined sample scenarios. Text
fields, search filters, pagination, sending messages, account changes and payment
processing do not operate on live data. Sample people, requests, dates, prices
and metrics illustrate the project. Map and portfolio graphics are editable
illustrations. Only the original logo uses raster image fills.

## Product rules preserved

- An accepted estimate leads to a **pending booking**, which the professional
  must accept or reject.
- Customers may cancel pending or accepted bookings. Professionals mark accepted
  work completed. Reviews require completed work and are limited to one per
  booking.
- Business contact is public; quotations, bookings and conversations are scoped
  to participants.
- Staff manage verification, review visibility, catalogue data, account access,
  reports and payment confirmation. Booking monitoring is read-only oversight.
- Promotion packages: Starter 1 day / BDT 100; Weekly 7 days / BDT 300; Half-Month
  15 days / BDT 500; Monthly 30 days / BDT 800. Staff can change packages.
- Promotion checkout concerns promotion purchases. Active, matching category and
  area, expiry and ranking quality still govern sponsored eligibility. Service
  settlement and escrow are outside this flow.

## Validation

Inspected the overview, component specimen, customer discovery/profile,
professional dashboard, staff dashboard and validation state. Corrected
horizontal auto-layout sizing so notices, metric cards and service categories
remain visible. Checked all pages for editable text, frames, components,
instances and vectors; all rendered text uses Inter. Raster fills reference only
the original logo. Main prototype routes have no missing or cross-page node
destinations. Shared variable scopes, semantic aliases and web syntax pass.

This deliverable adds a Figma design and handoff documentation. Flutter and
backend source files were not changed, and application tests were not rerun.

Sources: `README.md`, `docs/BRANDING.md`, `docs/PROPOSAL_COVERAGE.md`,
`docs/sprint-1/FLOWS_WIREFRAMES.md`, Flutter screen classes, and
`backend/public/admin.js` / `index.html`.
