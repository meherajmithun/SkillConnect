# Sharing SkillConnect with friends

## Install

For faculty review without hosting, send `SkillConnect-demo-v1.2.1.apk`.
It opens the interactive offline demo automatically and preserves local changes.
Use Account → Switch demo account to choose a role, and the link icon to reset the sample data or
connect to a live server. See the [faculty walkthrough](FACULTY_DEMO.md).

Send `SkillConnect-friends-v1.1.2.apk` to your friends. On Android, open it and permit installation from the app used to open the file if prompted. The universal APK supports ARM64, ARMv7 and x86_64. This is a development-key-signed testing release, not a Play Store release.

## Connect on the same Wi-Fi

1. Keep the hosting computer and phones on the same Wi-Fi network.
2. Start the Python backend with your computer's IP allowed:

   ```sh
   source .venv/bin/activate
   export ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2,YOUR_COMPUTER_IP
   python backend/manage.py runserver 0.0.0.0:8000
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
  --dart-define=ALLOW_HTTP=true \
  --dart-define=API_URL=http://YOUR_COMPUTER_IP:8000/api/
```

The output is `mobile/build/app/outputs/flutter-apk/app-release.apk`. GitHub Actions provides a downloadable `SkillConnect-friends-apk` artifact for repository runs. APKs are kept outside Git history to avoid adding large generated binaries.

For production, use your own signing key, HTTPS hosting and an HTTPS `API_URL`. Omit `ALLOW_HTTP=true`; the production manifest rejects cleartext traffic and the connection settings reject HTTP addresses.

Version 1.2.1 uses build number 7 and can update earlier friends APKs signed with the same development key. Apply backend migrations when connecting to the live backend. See [app updates](APP_UPDATES.md).

To rebuild the faculty demo, add `--dart-define=DEMO_MODE=true` to the rebuild
command above. GitHub Actions also uploads `SkillConnect-offline-demo-apk`.
