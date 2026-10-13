# 1.2 Project planning

## Objective and delivery approach

Sprint 1 produces an agreed implementation-ready product baseline: requirements,
scope, stakeholders, user journeys, wireframes, a visual prototype and a working
development environment. This repository has already progressed beyond Sprint 1;
the plan documents the WBS sequence and closes its missing planning artifacts.

Use four two-week sprints. Week/day labels are relative working days, not invented
calendar commitments. Named owners are to be assigned to the roles below. Effort
is an initial estimate in focused person-days; review and integration are included.

## Eight-week roadmap

| Sprint | Weeks | WBS / planned outcome | Dependencies | Exit evidence |
| --- | --- | --- | --- | --- |
| 1 | 1–2 | 1.1–1.6 Planning, stakeholders, flows, UI/prototype, environment | WBS, project scope, repository access | This package, tested prototype, baseline checks, stakeholder review |
| 2 | 3–4 | 2.1 Auth; 2.2 customer search/profile/quotes; 2.3 business/availability; 2.4 database/API | Requirements and design baseline | Integrated customer/professional journeys and permission tests |
| 3 | 5–6 | 3.1 booking/tracking; 3.2 reviews; 3.3 promotions; 3.4 admin; 3.5 notifications/integrations | Stable identity, profiles and request API | Lifecycle tests, scoped promotions, moderation and notification demo |
| 4 | 7–8 | 4.1–4.6 unit/integration/system/UAT, fixes, deployment, documentation | End-to-end integrated app and hosting decisions | UAT evidence, release build, configured deployment, handover |

Most Sprint 2–3 code already exists. Their next work should be gap verification
and stakeholder feedback, not rebuilding implemented modules. The current test
suite is evidence for that review, not evidence of completed external UAT.

## Sprint 1 backlog

| ID / WBS | Task | Owner role | Estimate | Dependency | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| S1-01 / 1.1 | Inspect modules, screens, models, tests and proposal coverage | Analyst + technical lead | 0.5 d | Repository | Findings table with source paths |
| S1-02 / 1.1 | Requirements, exclusions, acceptance criteria and traceability | Analyst | 1 d | S1-01 | FR/NFR register, assumptions and decisions |
| S1-03 / 1.3 | Stakeholder map, responsibility matrix and interview plan | Product/project lead | 0.5 d | S1-01 | Stakeholder needs and decision owners |
| S1-04 / 1.2 | Roadmap, backlog, dependencies, risks and done criteria | Project lead | 0.5 d | S1-02, S1-03 | Four-sprint roadmap and actionable Sprint 1 tasks |
| S1-05 / 1.4 | Information architecture, role journeys and error states | UX designer | 1 d | S1-02 | Customer/professional/staff flows and wireframes |
| S1-06 / 1.5 | Visual tokens and interactive mobile prototype | Designer + frontend developer | 2 d | S1-05 | Search → profile → quote → activity; business edit/availability; wireframe mode |
| S1-07 / 1.6 | Reproducible setup, preview targets and onboarding guide | Developer | 1 d | S1-01 | Documented install/run/check sequence and verified local toolchain |
| S1-08 / 1.5–1.6 | Check prototype and run baseline suites | QA + developer | 0.5 d | S1-06, S1-07 | Validation record and known limitations |
| S1-09 / all | Review requirements/prototype with stakeholders | Product owner + representatives | 0.5 d | S1-02–08 | Recorded feedback and explicit decisions; still pending |
| S1-10 / 1.2 | Refine next sprint backlog and retrospective | Project lead + team | 0.5 d | S1-09 | Prioritized changes and agreed next-sprint scope; pending review |

Estimate total: **8 person-days**, with two working days of a ten-day single-person
schedule reserved for review delays/fixes. Actual team capacity is unknown; assign
names and adjust estimates before using this as a commitment.

## Suggested working-day sequence

| Day | Focus | Review point |
| --- | --- | --- |
| 1 | Repository inventory, local tools, stakeholder identification | Agree the problem and known implementation |
| 2 | Requirements and scope boundaries | Review priority and exclusions |
| 3 | Backlog, risks, environment setup | Verify health and automated baseline |
| 4–5 | User flows, information architecture, wireframes | Walk customer/professional paths |
| 6–7 | Visual specification and interactive prototype | Check core journeys and failure states |
| 8 | Prototype verification and usability sessions | Record observations without inventing results |
| 9 | Feedback fixes and requirements/design review | Record accept/change/defer decisions |
| 10 | Sprint review, retrospective and Sprint 2 refinement | Publish artifacts and remaining actions |

## Risks and responses

| Risk | Impact / likelihood | Response | Owner |
| --- | --- | --- | --- |
| Existing advanced features blur Sprint 1 scope | High / high | Mark implementation evidence separately; build the missing planning package. | Project lead |
| Assumed user needs go unvalidated | High / medium | Recruit customers/professionals; run tasks from STAKEHOLDERS.md before sign-off. | Product owner |
| No local phone emulator | Medium / observed | Use Flutter web and the phone prototype now; assign native device validation later. | Developer / QA |
| SMTP, Firebase or merchant credentials unavailable | Medium / high | Use console email/manual promotions/in-app notifications locally; assign integration owners. | Backend lead |
| Documentation drifts from working tree | Medium / medium | Link requirements to code/tests; update traceability in each feature PR. | Technical lead |
| Team capacity/dates not supplied | Medium / observed | Use relative days and role-based owners until assigned. | Project lead |
| Setup differs across machines | Medium / medium | Publish observed versions and explicit tool overrides; run a fresh-machine check before handover. | Developer |

## Working agreements and review gates

- Daily short check-in: completed work, next task, blockers.
- Every change references a requirement or WBS item and contains reviewable evidence.
- Ready for implementation: user, goal, acceptance criteria, errors and API/data
  ownership are understood; dependencies are available or explicitly simulated.
- Done for Sprint 1 artifact work: internally consistent, linked, runnable where
  relevant, checked and with limitations recorded. Stakeholder acceptance is a
  separate decision and must not be inferred from tests passing.
- Sprint review: demonstrate journeys, collect feedback and record decisions.
  Retrospective: one thing to retain, one obstacle and one next-sprint improvement.

## Next-sprint refinement candidates

| Candidate | Reason | Next action |
| --- | --- | --- |
| Verify real customer/professional end-to-end journeys | Core code already exists | Execute real-backend scenarios with seeded accounts and record results |
| Preserve requested action after sign-in | Prototype demonstrates continuation | Review current profile/auth navigation and implement only after design agreement |
| Mobile discovery hierarchy | Existing large introduction precedes filters | Compare prototype with real app in usability tasks |
| Native build/device baseline | No emulator was available locally | Install/configure a device target and run native smoke checks |
| Research findings and localization | No interviews/Bangla UI evidence | Validate language/area needs before committing expansion |
