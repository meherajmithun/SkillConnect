# 1.5 UI design & prototype

## Direction

Design for a Dhaka resident finding a local professional and a professional
responding to work. The primary job is to make service, area and evidence clear
before asking for an account. Keep SkillConnect's existing blue, ink and teal
identity, recognizable language and role-based navigation.

Two hierarchy options were considered: retaining the large introductory hero
above all filters, or a compact introduction followed immediately by service/area
selection. The prototype uses the compact version to keep search reachable on a
phone. It is a design proposal, not an unreviewed rewrite of the Flutter screens.

The characteristic element is the **service-and-area strip**: the same selected
skill/place pair appears in results, profile and request context. It helps people
confirm that the request still concerns the right kind of work and location.
Professional names, example work and starting prices come from the demo seed;
additional prototype state is clearly labeled as sample data.

## Tokens and component specification

Baseline source: `mobile/lib/ui.dart`; icon provenance: `docs/BRANDING.md`.

| Token | Value | Use |
| --- | --- | --- |
| Ink | `#122B45` | Headings and main text |
| Blue | `#2358D5` | Primary action, active navigation, focus |
| Mist | `#F1F5FB` | Page and input surroundings |
| Teal | `#0A786E` | Availability and verification text |
| White | `#FFFFFF` | Cards and fields |
| Coral | `#E97759` | Decorative accent only; not small text on white |

Supporting border `#D5DFEC`, muted text `#52657A`, error `#B42318` and mint
background `#E7F5F1` serve semantic roles. Status always includes words.

- **Display:** local Avenir Next, falling back to the system sans-serif; 28/32px,
  bold, restrained negative tracking. The production app currently uses sans-serif.
- **Body/controls:** system UI sans-serif, 14–16px, line height 1.4–1.5.
- **Utility:** system monospace for the sample request reference only.
- **Spacing:** 4px base; 8/12px related controls; 16px card padding; 24px sections.
- **Shapes:** 14px input, 12px button, 20px card, matching the existing theme.
- **Touch:** controls at least 44px high; primary actions 48px or taller.
- **Layout:** phone content width 393px at desktop; fluid 360px and below;
  independently scrolling screen above bottom navigation. Desktop review tools
  sit outside the simulated app and wrap above it on narrow screens.
- **Motion:** optional loading indicator only; respect reduced-motion preference.

## Components

| Component | Required content / behavior |
| --- | --- |
| Search form | Visible labels for service, area and optional text; submit by button or Enter |
| Professional card | Name, skill, area, rating, starting price, verification words and profile action |
| Context strip | Selected service / area; same terminology throughout the request |
| Profile | About, skills, experience, portfolio/review sample and explicit request action |
| Request form | Professional context, service/area selectors, description, required-field validation |
| Quote card | Reference, participants, description, status and answer when present |
| Business editor | Name, biography, skills, served areas and non-negative starting price |
| Availability switch | Current available/paused state and consequence for new requests |
| Feedback | Polite live status; field validation; no status conveyed by color alone |
| Bottom navigation | Customer: Discover/Activity/Account; professional adds My business |

## Prototype coverage and limits

Open [prototype/index.html](prototype/index.html) or run `make prototype`.

Working interactions: search/filter, profile inspection, demo authentication gate,
quote form validation/submission, role switching, professional quote reply,
customer reply inspection, business editing, availability, sample staff
verification, loading/empty/offline previews, wireframe mode and reset.

All data is in memory. Reload/reset restores fixtures. No account, database,
notification, payment or external contact is created. Demo sign-in deliberately
uses a “Continue” action without collecting credentials; actual registration/login
is documented and already implemented in Flutter. The Staff view explains a
decision flow; it does not replace the JavaScript administration console.

Comparison, map, booking, reviews, portfolio uploads, calendar, promotions,
password recovery and messaging are documented/implemented elsewhere and are
outside this focused clickable prototype. No dead buttons are used for them.

## Accessibility and review checklist

- [x] Semantic headings, forms, buttons and labels; keyboard activation.
- [x] Visible focus indicator and polite feedback announcements.
- [x] Errors retain inputs; required fields use browser constraint validation.
- [x] Text labels accompany status and verification color.
- [x] Small-screen layout and reduced-motion styles.
- [ ] Screen-reader session and text scaling audit on target native devices.
- [ ] Stakeholder usability tasks from [STAKEHOLDERS.md](STAKEHOLDERS.md).

## Handoff

Keep requirement IDs in follow-up tasks. Before porting the compact search or
post-login continuation into Flutter, compare it with the current screens and
record the design decision. Reuse `appTheme`, `PageBody`, shared input/button
styles and `BrandIcon`; avoid introducing a second production design system.
Verify authenticated behavior with the real API, because prototype validation
does not establish server permissions or transaction integrity.
