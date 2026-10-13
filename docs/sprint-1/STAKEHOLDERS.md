# 1.3 Stakeholder identification

Stakeholders are identified by role. Names, interview participants and availability
have not been supplied. The needs below are hypotheses supported by the product
scope and code, not findings from completed interviews.

| Stakeholder | Goal / concern | Influence / interest | How to involve |
| --- | --- | --- | --- |
| Customer / local resident | Find a suitable provider, understand price, track requests and report problems | Medium / high | Discovery, quotation and booking usability sessions |
| Skilled professional / small business | Build trust, receive relevant requests, control availability and promotion spend | Medium / high | Profile setup, quote reply and promotion walkthrough |
| Marketplace administrator / moderator | Maintain catalogs, verification, reports and review quality | High / high | Review staff permissions and moderation rules |
| Product owner / project sponsor | Scope, value, priorities and acceptance | High / high | Requirements decisions and sprint review |
| Academic supervisor / evaluator, if applicable | WBS coverage, evidence and project learning outcomes | High / high | Review traceability and deliverable package; confirm role/name |
| Project lead / Scrum facilitator | Capacity, dependencies, delivery and blockers | High / high | Backlog refinement, check-ins and review coordination |
| UX designer / frontend developer | Usable mobile flows and consistent components | High / high | Wireframe/prototype reviews and implementation handoff |
| Backend developer / technical lead | Authorization, data integrity, API and maintainability | High / high | Requirements/API review, migrations and automated checks |
| QA / testers | Reproducible behavior, failure states and regressions | Medium / high | Acceptance scenarios, device checks and evidence |
| Operations / finance owner | Payment confirmation, promotion pricing and incident handling | High / medium | Approve operational workflow and responsibilities |
| Hosting, email, payment and push providers | Configuration and delivery requirements | External dependency / medium | Technical setup in later sprints; no commitments assumed |

## Responsibility matrix

R = performs work; A = decision/accountability owner; C = consulted; I = informed.
One person may hold several roles. Each row has one accountable role.

| Deliverable / decision | Product owner | Project lead | Analyst / UX | Developer | QA | User representatives |
| --- | --- | --- | --- | --- | --- | --- |
| Scope and requirement acceptance | A | C | R | C | C | C |
| Sprint schedule and capacity | C | A/R | C | C | C | I |
| Research recruitment | A | R | R | I | C | C |
| Flows, wireframes and prototype | A | I | R | C | C | C |
| Development setup / architecture baseline | I | C | C | A/R | C | I |
| Acceptance checks and evidence | I | A | C | R | R | C |
| Sprint review and next-sprint refinement | A | R | C | C | C | C |

Staff verification criteria and payment-confirmation rules require consultation
with the administrator/operations roles in addition to this delivery matrix.

## Research plan

Recruit **3 customers, 3 professionals and 1 administrator** if available. This is
a proposed small formative sample, not a representative market survey. Sessions
can be 20–30 minutes. Use fictional work, addresses and credentials in the demo.
Ask permission before recording; keep findings anonymized.

Questions for customers:

1. How did you find your last local service provider? What was difficult?
2. What evidence makes you comfortable contacting someone: work, price, reviews,
   verification or a recommendation? What does “verified” mean to you?
3. When do you need a quotation before booking? What information can you provide?
4. What should happen if the professional is unavailable or does not respond?
5. Which language and geographic area should the first release support?

Questions for professionals:

1. How do customers currently find you and agree on price/time?
2. What work examples can you share, and what should remain private?
3. How do you pause new work, handle requests and update availability?
4. What information do you need to price a request?
5. How would you decide whether an area-specific promotion is useful?

Questions for staff:

1. What evidence is required to verify a professional, and who owns that decision?
2. How should complaints and hidden reviews be recorded and resolved?
3. Who confirms payments and changes package prices?
4. Who handles account access, data correction and support requests?

## Prototype tasks and proposed success measures

| Task | Participant | Observe |
| --- | --- | --- |
| Find an electrician in Mirpur and inspect their work | Customer | Filter comprehension, profile evidence found, wrong turns |
| Request an estimate for a switchboard repair and find its status | Customer | Completion without assistance, validation recovery, where they expect a reply |
| Change service areas and pause new requests | Professional | Label comprehension, save feedback, availability understanding |
| Reply to a customer's estimate request | Professional | Amount/terms clarity, ability to locate the request |
| Review a verification decision | Administrator | Evidence expectations and permission boundaries |

Proposed formative target: at least 5 of 6 customer/professional participants
complete their relevant core task without facilitator intervention. Record time,
assistance and errors; do not treat this sample as a statistical usability claim.

## Feedback and decision log template

No sessions or approvals have been recorded yet. Copy one row per observation.

| Date / anonymized participant | Task / requirement ID | Observation | Severity | Decision / rationale | Owner / target sprint |
| --- | --- | --- | --- | --- | --- |
| Pending | — | — | — | — | — |

Review decisions use **accept**, **change** or **defer**, with a named decision
owner and date. Passing code tests does not substitute for stakeholder acceptance.
