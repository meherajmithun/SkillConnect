# SkillConnect on Render

The root `render.yaml` deploys the JavaScript API and PostgreSQL in Singapore.
It generates a JWT secret and supplies the private database connection. The API
binds Render's port, migrates its schema on startup, and derives an exact host
allowlist and HTTPS origin from Render's assigned hostname. It does not run the
demo seed, import the local database, or create sample accounts.

## Deploy

1. Install and connect the Render integration to let the assistant deploy into
   your workspace, or open [Deploy to Render](https://render.com/deploy?repo=https://github.com/meherajmithun/SkillConnect).
2. Sign in, connect this GitHub repository, and review the Blueprint. The
   default file selects free services; review Render's summary before creating.
3. Wait for the database and web service to become available. Copy the actual
   HTTPS address from the service dashboard; the service name alone does not
   guarantee a particular public address.
4. Open `https://YOUR_RENDER_HOST/api/health/`. It should return `status: ok`
   and `backend: nodejs`. Open `/api/categories/` and `/api/professionals/`
   to confirm the live database is reachable.

The assistant cannot claim a live deployment or build an APK with a confirmed
Render address until the account connection and deployment have completed.

## Real accounts and catalogue

Register your own customer and professional accounts in Flutter. This is a new
database, so records stored on the computer are not automatically available.
Populate real service categories, areas and promotion packages through `/admin/`.
For a paid web service, create your administrator from the Render Shell:

```sh
ADMIN_USERNAME=your_username ADMIN_EMAIL=your_email \
ADMIN_PASSWORD='your-strong-password' npm run admin
```

Free services have no Shell access. Create your administrator by running the
same command locally against the Render database's **external** connection URL
with `DATABASE_SSL=true` and a temporary database inbound rule for your own IP.
Supply credentials through a private local environment file; never commit them.
Remove the temporary inbound rule afterward. Never run `npm run seed` for this
deployment. No local sample profiles or accounts are uploaded by the Blueprint.

## Connect the phone

The existing live APK can use the hosted API: tap the link icon, enter
`https://YOUR_RENDER_HOST/api/`, and tap **Test connection & save**. This removes
the requirement for the computer to stay on or share the phone's Wi-Fi.

For a new APK with the Render address as its default:

```sh
cd mobile
flutter build apk --release --build-name=2.0.1 --build-number=9 \
  --dart-define=DEMO_AVAILABLE=false \
  --dart-define=DEMO_MODE=false \
  --dart-define=API_URL=https://YOUR_RENDER_HOST/api/
```

The APK is `mobile/build/app/outputs/flutter-apk/app-release.apk`. Use the same
signing key as previous builds to install it as an update. A phone with a saved
PC API address still needs the hosted address saved in the connection settings.

## Hosting limits and ongoing use

The default Blueprint is for a short faculty review. Free web services sleep
after 15 minutes of inactivity and may take about a minute to wake. Open the
health URL in the phone browser before the review if necessary. Free PostgreSQL
expires after 30 days. Uploaded photos use the web filesystem and will be lost
on a free service restart, redeploy or sleep. See [Render free-service limits](https://render.com/docs/free).

For ongoing use, select paid web and database plans in the dashboard. Attach a
persistent disk mounted at `/var/data` and set `MEDIA_DIR=/var/data/media` to
preserve uploaded photos. Keep these settings in the Blueprint when managing
the deployment with it. Paid resources incur charges; review [Render pricing](https://render.com/pricing)
before creating or upgrading them.

Payments stay disabled until real SSLCommerz credentials and a hosted callback
origin are configured. Firebase push requires its credentials and a worker.
Password recovery requires actual email delivery; free services block common
SMTP ports. No simulated payments or recovery delivery are enabled here.
