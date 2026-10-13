# Sprint 1 — Planning & UI/UX

**SkillConnect · Week 1–2 · WBS 1.1–1.6**
Prepared against the working tree on **10 October 2026** and the supplied WBS.

This is the planning and design baseline for an existing implementation. The
repository already includes core development and advanced features assigned to
Sprints 2–3 in the WBS. They are recorded as implementation evidence, not work
newly completed in Sprint 1. Dates below are relative; team names and calendar
dates have not been supplied. Stakeholder approval and user research remain open.

## Deliverables

| WBS | Work package | Deliverable | Status |
| --- | --- | --- | --- |
| 1.1 | Requirement analysis | [Requirements, scope and acceptance criteria](REQUIREMENTS.md) | Prepared from code and project documents |
| 1.2 | Project planning | [Sprint plan, backlog, dependencies and risks](PLAN.md) | Prepared; role-based owners |
| 1.3 | Stakeholder identification | [Stakeholders, responsibilities and research plan](STAKEHOLDERS.md) | Prepared; participants to be assigned |
| 1.4 | User flow & wireframes | [Journeys, state diagrams and mobile wireframes](FLOWS_WIREFRAMES.md) | Prepared; low-fidelity mode also available in prototype |
| 1.5 | UI design & prototype | [Design specification](DESIGN.md) and [interactive prototype](prototype/index.html) | Implemented with sample data |
| 1.6 | Development environment setup | [Setup and troubleshooting](SETUP.md), Make targets | Local baseline verified; native device setup pending |

Start the design prototype from the repository root:

```sh
make prototype
```

Open **http://localhost:8082**. It runs without Django, Flutter, credentials or
network services. The desktop design board contains an interactive mobile frame;
on a small screen it expands to the available width. Use **Wireframe** to inspect
the same flows without the visual treatment. **Reset demo** clears sample changes.
Opening `prototype/index.html` directly also works.

## Codebase findings

| Area | Evidence inspected | Finding / Sprint 1 implication |
| --- | --- | --- |
| Architecture | `backend/config/settings.py`, `mobile/lib/api.dart` | Flutter client + Django REST API, JWT auth; SQLite locally and PostgreSQL configured for deployment. Document the existing choice. |
| Roles and data | `backend/marketplace/models.py`, `serializers.py`, `views.py`, `admin.py` | Customer/professional roles and staff administration; profile, booking, quote, review, promotion and notification entities exist. Specify permission boundaries. |
| Navigation and UI | `mobile/lib/main.dart`, `ui.dart`, `screens/` | Discover / Activity / Account, plus My business for professionals. Retain labels and brand tokens in the prototype. |
| Core journeys | `screens/discover.dart`, `activity.dart`, `professional.dart` | Search, profile comparison, quotes, bookings, reviews, portfolio and availability are already implemented. Document their states and requirements. |
| Additional integrations | `accounts.py`, `scheduling.py`, `conversations.py`, `payments.py`, `push.dart` | Recovery, calendar, messages, checkout and push are present; live providers need configuration. Keep them distinct from Sprint 1 design work. |
| Planning assets | Existing `docs/` before this work | API, proposal coverage, branding and deployment notes existed. No Sprint 1 requirements register, role matrix, sprint backlog, or flow/wireframe package was found. |
| Setup | `Makefile`, manifests, `.env.example`, CI | Dependencies and checks existed. Added a focused onboarding guide, dependency/seed/doctor/prototype targets and a useful mobile README. |
| Verification | Existing backend and Flutter suites | [Validation record](VALIDATION.md) contains actual results and their limits. |

## Review walkthrough

1. In the prototype, search **Electrician / Mirpur**, open Rahim's profile and
   request a quote. Try the form empty, then enter a work description and submit.
   Open Activity to see the request. Guest actions lead through demo sign-in.
2. Switch to **Professional**, edit the business profile and pause availability.
   Open Activity, reply to the customer's quote, then switch to Customer to view
   the reply. The simulation is local to this page.
3. Inspect the **Staff** view to review the proposed verification decision. The
   actual staff application remains Django admin; this small-screen sketch is
   a process illustration.
4. Select Wireframe and check hierarchy, labels and paths. Review the documented
   booking lifecycle and promotion rules for the later sprints.
5. Run setup checks and compare the real Flutter app with the documented baseline.

## Definition of done

- [x] Every WBS 1.x item has a linked artifact.
- [x] Functional requirements have IDs, acceptance criteria and code evidence.
- [x] Stakeholders and decision owners are identified by role.
- [x] Four-sprint plan, Sprint 1 tasks, dependencies and risks are recorded.
- [x] Customer, professional and staff journeys include failure/empty states.
- [x] Wireframes, visual tokens and an interactive mobile prototype are available.
- [x] Local setup and existing automated checks have been exercised.
- [ ] Named stakeholder review, usability sessions and scope/design acceptance.
- [ ] Native Android/iOS device validation when an emulator or device is available.

The deliverables are ready for review. The unchecked items require people or
devices and are not represented as completed research or approvals.
