# SkillConnect on Vercel

This repository is configured as one Vercel project:

- `/` serves the compiled Flutter web app.
- `/api/` runs the Express backend as a Vercel Function.
- `/admin/` serves the staff administration page.
- PostgreSQL keeps accounts and marketplace data persistent.
- Vercel Blob keeps portfolio images persistent.

The build downloads the pinned Flutter 3.47.2 SDK when Vercel does not already
provide Flutter. The first build therefore takes longer than a normal Node.js
build.

## 1. Import the repository

1. Push the Vercel configuration changes to GitHub.
2. In Vercel, choose **Add New → Project** and import the `SkillConnect`
   repository.
3. Keep the **Root Directory** as the repository root (`.`).
4. Select **Other** as the framework preset. Do not override the build command
   or output directory; `vercel.json` supplies both.

Do not select `mobile` or `backend` as the Root Directory. Each choice would
hide the other half of the application from the build.

## 2. Add PostgreSQL

The production backend intentionally refuses to start with SQLite because a
Vercel Function does not have a persistent local disk.

1. Open the Vercel project's **Storage** tab.
2. Create a PostgreSQL database from the Marketplace. Neon is a suitable
   serverless option; choose a region near the Vercel Function when possible.
3. Connect it to Production and Preview environments.
4. Confirm that the integration added `DATABASE_URL` to the project. If the
   provider used a prefixed name, add `DATABASE_URL` with the same connection
   string.
5. Add `DATABASE_SSL=true` unless the provider explicitly documents a
   non-TLS connection.

Tables and the initial category, area, and package catalogue are created on the
first successful API request. Do not run the demo seed against production.

## 3. Add portfolio image storage

1. In the same **Storage** tab, create a **Blob** store with **Public** access.
2. Connect it to Production and Preview environments.

Vercel supplies the Blob credentials to the Function. Without a connected Blob
store, the rest of the app works, but portfolio image uploads return a clear
`503` response instead of pretending that a temporary upload is persistent.
Vercel Functions limit request bodies to 4.5 MB, so this deployment accepts
portfolio source images up to 4 MB.

## 4. Add required environment variables

In **Settings → Environment Variables**, add these to Production and Preview:

| Name | Value |
| --- | --- |
| `JWT_SECRET` | A new random secret of at least 32 characters |
| `DATABASE_SSL` | `true` for normal hosted PostgreSQL providers |

Generate a suitable JWT secret locally with:

```sh
openssl rand -base64 48
```

Do not commit the generated value. The generated `*.vercel.app` hostnames are
detected automatically. If a custom domain is added later, set `ALLOWED_HOSTS`
to a comma-separated list containing the custom domain and the production
`*.vercel.app` domain, and set `PUBLIC_ORIGIN` to the custom HTTPS origin.

Email delivery, Firebase push notifications, and SSLCommerz payments remain
optional integrations. Add their variables from `.env.example` only when those
services are ready. Never enable demo payments in production.

## 5. Deploy and verify

Select **Deploy**. After the build succeeds, open these URLs in order:

1. `https://YOUR-PROJECT.vercel.app/api/health/` — must return JSON containing
   `"status":"ok"`.
2. `https://YOUR-PROJECT.vercel.app/api/categories/` — must return catalogue
   data from PostgreSQL.
3. `https://YOUR-PROJECT.vercel.app/` — opens the phone-friendly Flutter app.
4. `https://YOUR-PROJECT.vercel.app/admin/` — opens the staff login page.

Open the root URL from the phone. The Flutter web build derives `/api/` from
the current HTTPS origin automatically, so no server address needs to be typed
and custom domains continue to work.

If the API returns `500`, open the Vercel Function logs. The most common causes
are a missing `DATABASE_URL`, a `JWT_SECRET` shorter than 32 characters, or a
database connection that requires `DATABASE_SSL=true`.

## Staff account

The deployment creates no default administrator. Create one by running the
existing admin command from a trusted machine with the hosted `DATABASE_URL`
temporarily loaded into the shell:

```sh
ADMIN_USERNAME=admin \
ADMIN_EMAIL=you@example.com \
ADMIN_PASSWORD='choose-a-strong-password' \
ADMIN_ROLE=super_admin \
DATABASE_URL='your-hosted-postgres-connection-string' \
DATABASE_SSL=true \
npm run admin
```

Keep the database connection string out of terminal screenshots, shell history,
source control, and chat messages.
