# Faculty demonstration · SkillConnect 1.2.0

Install `dist/SkillConnect-demo-v1.2.0.apk` on an Android phone. This build opens
the offline demo automatically, signed in as a sample customer. No hosting,
computer connection, internet, or registration is needed to explore the app.
The **Offline demo** banner identifies sample data. Changes are saved on that
phone; other people cannot see them. If the app was previously switched to live
mode, use the link icon → **Start offline demo**.

## Suggested five-minute walkthrough

1. **Discover:** browse six sample professionals, change service and area,
   search, sort, compare profiles, view a profile and its previous work. The
   offline location view has interactive sample pins rather than online tiles.
2. **Customer requests:** on Rahim Electrical Works, send a quotation request.
   Return to Activity → Quotes to find it. A prefilled answered estimate is also
   available so the reviewer can immediately try accepting an estimate and
   choosing an appointment.
3. **Professional:** tap **Try professional** in the banner. Activity → Quotes
   shows the same customer's request. Send an estimate; send a message. My
   business provides profile editing, portfolio projects, calendar management,
   statistics, and simulated promotion activation.
4. **Booking:** switch with **Try customer**, accept the estimate, choose a free
   appointment and enter a sample address. Switch to the professional, open
   Activity, accept the booking, then mark it completed. Return to the customer
   and publish a review. A completed sample booking is available from the start.
5. **Account:** edit sample account details, try email verification, view
   notifications or add a demo notification. The sample verification/reset
   code is **12345678**; no email is sent. Sign-out and local registration can
   also be demonstrated. Use sample details for local registration.

The banner's role switch always returns to the main screen so a customer is
not left inside a professional-only form. Use the link icon → **Reset demo data**
to restore the original sample accounts and requests before another review.
Reset requires confirmation. It changes only the local demonstration data.

If signing in manually, use `demo_customer` or `demo_pro` with password
`Demo1234!`. These are local sample credentials, unrelated to live accounts.

## Explain the project accurately

| Likely question | Explanation |
| --- | --- |
| What problem does this solve? | Customers find local skilled professionals; professionals present their work and receive service requests. |
| What is the architecture? | Flutter/Dart frontend, Django REST Framework API with JWT authentication, PostgreSQL for deployment and SQLite for local development. |
| Why does this APK work offline? | A separate local demo store supplies sample API responses and saves changes in device storage. This demonstrates interaction flows; live use calls the Django API. |
| Is the backend implemented? | Yes: accounts, discovery, quotations, scheduling, bookings, reviews, promotions, messages and moderation/admin APIs are implemented and have automated tests. |
| What prevents duplicate bookings? | The backend reserves pending/accepted times, checks overlaps and uses transactions and professional row locks. The local demo also rejects overlapping reservations. |
| How are roles handled? | Live API permissions separate customers and professionals. The demo switch is a presentation tool for two sample accounts on one phone. |
| Are these real providers or payments? | They are sample providers. Demo promotion activation charges no money; the call button shows a preview instead of dialing. Live payment checkout needs merchant credentials and provider testing. |
| Do emails and push notifications work here? | Demo email codes and notifications are local simulations. Real delivery needs SMTP and Firebase/APNs configuration and device checks. |
| Can customers on different phones interact? | That requires the hosted API and shared database. Each offline demo installation has independent data. |
| What remains before deployment? | Choose hosting, configure HTTPS/PostgreSQL and persistent media, provision provider credentials if used, and complete real-device/user acceptance checks. |

The offline demo is evidence that the initial product structure and interaction
flows are ready for faculty review. It does not certify production deployment,
real payments, external email/push delivery, or human acceptance.

## Build validation

Flutter analysis passed and all 16 tests passed, including offline request
lifecycles, persistence, live-session isolation and clickable flows at 360 px
and 1000 px. The Android release build passed. Package `com.skillconnect.mobile`
has version `1.2.0`, version code `6`, and the same development signing
certificate as the previous friends APKs. Physical-device faculty acceptance
is still to be recorded after installation.

APK SHA-256: `6942e69b0c0015ef85438fb72bc0748fe1d7f50d2d76cd976d458a514b08b6db`.
