# SkillConnect faculty app plan

Prepared 19 October 2026 from the current working tree, original proposal, WBS and project documentation.

Visual polish updated 21 October 2026 across all ten presentation frames.

- [Open the Figma design](https://www.figma.com/design/Y1xMqlHzsHUpForDvi4Gyc?node-id=2-2)
- [Open the presentation](https://www.figma.com/proto/Y1xMqlHzsHUpForDvi4Gyc?node-id=2-2&starting-point-node-id=2%3A2)
- Updated cover preview: `faculty-plan-cover.png` in this folder.
- Original overview before the visual polish: `faculty-plan-overview.png`.

## What the Figma file contains

Ten editable presentation frames with Next / Back navigation and nine illustrative mobile screens. The mobile layouts are condensed concepts for explaining the app; they are not exact captures of the Flutter UI. Example names, amounts, counts and appointment dates are sample data. Only presentation navigation is interactive; the mock app controls do not submit requests.

| Frame | Faculty discussion |
| --- | --- |
| 01 — Vision | Customer discovery problem, professional visibility and the three roles |
| 02 — Product system | Customer app, professional app, staff console and current architecture |
| 03 — Customer journey | Discover, evaluate, request, coordinate and review |
| 04 — App concept screens | Discovery, matching professional and quotation request |
| 05 — Quote, appointment and booking | Answered estimate, appointment choice and booking lifecycle |
| 06 — Business and trust | Provider capabilities, staff decisions and promotion boundaries |
| 07 — Professional app screens | My business, estimate reply and availability calendar |
| 08 — Revenue model | Free discovery/profile and configurable promotion packages |
| 09 — Original sprint plan | The four two-week sprints from WBS.png |
| 10 — Delivery plan | Implemented scope, next priorities and later extensions |

Start at frame 01 in Figma Present mode. Use Next and Back in the bottom right. The final frame links back to the beginning.

## Review findings that shaped the design

1. **The current project is a marketplace MVP.** Flutter supplies customer and professional experiences. Node.js/Express provides the API and serves a separate staff web console. PostgreSQL is configured for deployment; SQLite supports local development.
2. **The original proposal named a Python backend.** The implementation and migration documentation establish Node.js/Express as the revised technology. Frame 02 explicitly calls out this difference.
3. **Promotion is the proposal's main revenue model.** The proposal and `backend/src/catalogue.js` agree on Starter: 1 day / BDT 100; Weekly: 7 days / BDT 300; Half-Month: 15 days / BDT 500; Monthly: 30 days / BDT 800. Staff can change packages. Eligible paid promotions affect matching service-and-area searches until expiry; the ranking still considers other quality factors.
4. **An accepted estimate is not a confirmed appointment.** Quote acceptance snapshots the current amount and terms and creates a pending booking. The professional accepts or rejects it. Customers may cancel pending or accepted bookings; professionals mark accepted work completed. Reviews require completed work and are limited to one per booking.
5. **Business contact and private request data have different access rules.** Public profiles expose business contact. Quotes, bookings and messages are scoped to their participants. Staff controls verification, catalogue data, moderation and payment confirmation.
6. **Delivery dependencies remain.** SMTP, native Firebase/APNs and SSLCommerz require configured environments and real delivery/transaction validation. Persistent media, backups, release signing and physical-device acceptance remain priorities. Checkout currently concerns promotion purchases, not service settlement or escrow.
7. **The WBS is a planning artifact.** It describes weeks 1–8, not completed sprint dates. The Figma plan preserves that distinction. Existing source covers many features assigned to later sprints.
8. **Branding is already established.** The original blue/mint S-link asset is reused. Ink, royal blue, mist and teal come from `mobile/lib/ui.dart`. The polished presentation pairs Manrope headings with Inter body text; the Flutter theme uses the platform `sans-serif` family.

## Source coverage

| Area | Evidence reviewed |
| --- | --- |
| Original scope | All three pages of `SkillConnect_Project_Proposal.pdf`; `WBS.png` |
| Flutter structure and flows | `mobile/lib/main.dart`, `ui.dart`, feature screen classes, API/session handling, credentials, push and isolated demo store |
| Marketplace logic | `backend/src/marketplace.js`: discovery, public profiles, quotation revisions, booking conflicts/transitions, private messages, reviews, promotions and metrics |
| Supporting backend | Authentication routes, relational schema, database adapter, catalogue, uploads, administration, payment and push modules; seed/import/server/configuration responsibilities |
| Staff surface | `backend/public/index.html` and administration script structure |
| Delivery and checks | `render.yaml`, `compose.yaml`, `.github/workflows/ci.yml`, app manifest/version configuration and existing test coverage inventory |
| Design and documentation | README, project structure/state, proposal coverage, faculty demo, branding, role audit and Sprint 1 requirements/flows/stakeholders/planning |
| Visual assets | Original app icon, generated icon family, discovery/results screenshots and WBS artwork |

The earlier discovery screenshots use an older header mark; the current source asset is used in Figma. Generated platform icons are derivatives of that source rather than separate design directions.

## Validation of this deliverable

- The 21 October polish adds a split cover with editable app previews, consistent heading layouts, clearer navigation, refined phone frames, reusable journey cards and an emphasized weekly promotion example.
- Visually reviewed the complete polished canvas and the cover; confirmed Manrope/Inter typography and all 19 presentation destinations.
- Confirmed editable text, frames and component instances across all ten slides; image fills contain only the original logo asset.

- Inspected the completed Figma composition and corrected text sizing in auto layout cards.
- Checked that the content is editable text, frames and component instances. Raster fills are limited to the existing brand asset.
- Checked presentation destinations for 19 navigation links across ten frames.
- Confirmed sample-data labeling, proposal package values, current backend choice, role boundaries and original WBS timing.
- This was a source and design review. Application test suites and external integrations were not rerun; prior test results remain in the existing release/audit documents.
