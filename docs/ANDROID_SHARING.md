# Sharing SkillConnect with friends

## Install

The current hosted build is `dist/SkillConnect-v2.1.0.apk`, version 2.1.0,
build 10. It connects to `https://skillconnect-api-6bwr.onrender.com/api/` and is built with
`DEMO_AVAILABLE=false` and `DEMO_MODE=false`. Saved demo settings from earlier
APKs are ignored, and demo controls are hidden. It loads the records currently
stored on the backend; it does not bundle sample accounts or professionals.

Install it over the previous APK. Saved HTTP server settings automatically move
to Render and local-server login tokens are cleared. Register a new account or
sign in to an existing hosted account; the Render database is separate from the
computer's database. Internet is required, but the computer can stay off. The
free server can take about a minute to wake; this build allows 90 seconds for
Render requests. See [Render deployment](RENDER_DEPLOYMENT.md) for data and upload limits.

For faculty review without hosting, send `SkillConnect-demo-v1.2.1.apk`.
It opens the interactive offline demo automatically and preserves local changes.
Use Account → Switch demo account to choose a role, and the link icon to reset the sample data or
connect to a live server. See the [faculty walkthrough](FACULTY_DEMO.md).

Send `SkillConnect-v2.1.0.apk` to your friends. On Android, open it and permit installation from the app used to open the file if prompted. The universal APK supports ARM64, ARMv7 and x86_64. This is a development-key-signed testing release, not a Play Store release.

Both roles can sign in with email or username. Check **Save email and password**
to keep encrypted credentials on this device. On the next sign-in, tap a saved
account to fill both fields; use its × button to forget it. Android's configured
password manager can also suggest credentials. New providers open **My business**
and use **Choose services and areas** to finish setup before appearing in search.

## Connect on the same Wi-Fi

These steps require a separate local APK built with `ALLOW_HTTP=true`, as shown
under Rebuild. The hosted live APK accepts HTTPS addresses only.

1. Keep the hosting computer and phones on the same Wi-Fi network.
2. Start the Node.js backend with your computer's IP allowed:

   ```sh
   npm ci
   npm run migrate
   npm run dev
   ```

3. Open the link icon in the APK toolbar. Enter `http://YOUR_COMPUTER_IP:8000/api/` and tap **Test connection & save**.
4. Browse services. Create a customer account to book, or a professional account to add a business profile. Set at least one service and area on a new professional profile.

The local friends build defaults to `http://192.168.0.174:8000/api/`, the hosting computer's address when it was built. If the address changes, update it in the app. Guest Wi-Fi isolation and the host firewall may block connections; confirm that the phone can open `http://YOUR_COMPUTER_IP:8000/api/health/` in its browser.

The app layout is visible without a backend. Live services, accounts and bookings require the backend to be running. They will not work from a friend's other network unless you deploy the backend to a publicly reachable HTTPS host. Change the app's server URL to that deployment when available.

## Demo data

The local database includes sample professionals and completed reviews. Demo phone numbers are placeholders. Friends can register their own accounts. The local initial seeded-account password is in the ignored `.demo-password` file; do not publish it or use it for production accounts.

`DEMO_PAYMENTS=true` can be enabled on a local server to simulate promotion activation without charging money. The app labels this as demo checkout. Otherwise promotions wait for manual payment confirmation in admin.

## Rebuild

```sh
cd mobile
flutter build apk --release \
  --dart-define=DEMO_AVAILABLE=false \
  --dart-define=ALLOW_HTTP=true \
  --dart-define=API_URL=http://YOUR_COMPUTER_IP:8000/api/
```

The output is `mobile/build/app/outputs/flutter-apk/app-release.apk`. GitHub Actions provides a downloadable `SkillConnect-live-apk` artifact for repository runs, using the hosted HTTPS backend. APKs are kept outside Git history to avoid adding large generated binaries.

For production, use your own signing key, HTTPS hosting and an HTTPS `API_URL`. Omit `ALLOW_HTTP=true`; the production manifest rejects cleartext traffic and the connection settings reject HTTP addresses.

Version 2.0.0 uses build number 8 and can update earlier friends APKs signed with the same development key. Run `npm run migrate` when connecting to the live backend. See [app updates](APP_UPDATES.md).

To rebuild the faculty demo, use `--dart-define=DEMO_AVAILABLE=true` and
`--dart-define=DEMO_MODE=true`. GitHub Actions also uploads `SkillConnect-offline-demo-apk`.
