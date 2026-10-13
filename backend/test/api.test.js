import test, { beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { configuration } from "../src/config.js";
import { openDatabase } from "../src/db.js";
import { createApp } from "../src/app.js";
import { hashPassword } from "../src/auth.js";
import { timestamp } from "../src/validation.js";
import { deliverPush } from "../src/push-worker.js";
import sharp from "sharp";

let db, server, origin, config, world, directory, emails, gateway;
const password = "ExampleSecure2026!";
async function request(method, route, body, token, headers = {}) {
  const response = await fetch(`${origin}/api/${route}`, {
    method,
    headers: {
      ...(body != null ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    ...(body == null ? {} : { body: JSON.stringify(body) }),
  });
  const payload = await response.text();
  return {
    status: response.status,
    data: payload ? JSON.parse(payload) : null,
    headers: response.headers,
  };
}
async function login(username = "customer") {
  const r = await request("POST", "auth/login/", { username, password });
  assert.equal(r.status, 200);
  return r.data;
}
const future = (days) => new Date(Date.now() + days * 86400000).toISOString();
const bookingBody = () => ({
  professional: world.pro.id,
  category: world.category.id,
  area: world.area.id,
  scheduled_at: future(2),
  duration_minutes: 60,
  address: "Sample home",
  details: "Repair the lights",
});
async function booking() {
  const r = await request(
    "POST",
    "bookings/",
    bookingBody(),
    world.customerToken,
  );
  assert.equal(r.status, 201);
  return r.data;
}
async function quote() {
  const r = await request(
    "POST",
    "quotes/",
    bookingBody(),
    world.customerToken,
  );
  assert.equal(r.status, 201);
  return r.data;
}
async function purchase() {
  const r = await request(
    "POST",
    "promotions/",
    {
      package: world.package.id,
      category: world.category.id,
      area: world.area.id,
    },
    world.proToken,
  );
  assert.equal(r.status, 201);
  return r.data;
}

beforeEach(async () => {
  directory = await mkdtemp(path.join(tmpdir(), "skillconnect-js-test-"));
  emails = [];
  gateway = async () => {
    throw new Error("Unexpected external payment call.");
  };
  config = {
    ...configuration({ NODE_ENV: "test", SQLITE_PATH: ":memory:" }),
    databaseUrl: process.env.TEST_DATABASE_URL || "",
    mediaDir: path.join(directory, "media"),
    rateLimit: false,
    sendEmail: async (email) => emails.push(email),
    gatewayRequest: (...args) => gateway(...args),
  };
  db = await openDatabase(config);
  await db.migrate();
  if (db.postgres) {
    await db.query(
      "TRUNCATE users,categories,areas,packages RESTART IDENTITY CASCADE",
    );
    await db.query("DELETE FROM rate_limits");
  }
  world = await db.transaction(async (tx) => {
    const hash = await hashPassword(password);
    const user = async (username, role, is_staff = 0) =>
      tx.insert("users", {
        username,
        email: `${username}@example.com`,
        password: hash,
        first_name: username,
        last_name: "Example",
        phone: "+8801700000000",
        role,
        is_staff,
        created_at: timestamp(),
      });
    const customer = await user("customer", "customer"),
      professional = await user("professional", "professional"),
      stranger = await user("stranger", "customer"),
      staff = await user("staff", "customer", 1);
    const category = await tx.insert("categories", {
        name: "Electrician",
        icon: "bolt",
      }),
      area = await tx.insert("areas", {
        name: "Mirpur",
        city: "Dhaka",
        latitude: 23.82,
        longitude: 90.36,
      });
    const pro = await tx.insert("professionals", {
      user_id: professional.id,
      business_name: "Electrical Works",
      bio: "Careful work",
      latitude: 23.81,
      longitude: 90.37,
      starting_price: "450.00",
      created_at: timestamp(),
    });
    await tx.insert("professional_categories", {
      professional_id: pro.id,
      category_id: category.id,
    });
    await tx.insert("professional_areas", {
      professional_id: pro.id,
      area_id: area.id,
    });
    const pack = await tx.insert("packages", {
      name: "Weekly",
      days: 7,
      price: "300.00",
    });
    return {
      customer,
      professional,
      stranger,
      staff,
      category,
      area,
      pro,
      package: pack,
    };
  });
  server = createApp(db, config).listen(0, "127.0.0.1");
  await new Promise((resolve, reject) => {
    server.once("listening", resolve);
    server.once("error", reject);
  });
  origin = `http://127.0.0.1:${server.address().port}`;
  world.customerToken = (await login()).access;
  world.proToken = (await login("professional")).access;
  world.strangerToken = (await login("stranger")).access;
  world.staffToken = (await login("staff")).access;
});
afterEach(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
  if (db) await db.close();
  if (directory) await rm(directory, { recursive: true, force: true });
});

test("health, CORS, catalogue and Flutter response contract", async () => {
  const health = await request("GET", "health/");
  assert.equal(health.status, 200);
  assert.equal(health.data.backend, "nodejs");
  const categories = await request("GET", "categories/", null, null, {
    Origin: "http://localhost:8080",
  });
  assert.equal(
    categories.headers.get("access-control-allow-origin"),
    "http://localhost:8080",
  );
  assert.deepEqual(categories.data, [
    { id: world.category.id, name: "Electrician", icon: "bolt" },
  ]);
  const profiles = (await request("GET", "professionals/")).data;
  assert.equal(profiles.count, 1);
  assert.equal(typeof profiles.results[0].available, "boolean");
  assert.equal(profiles.results[0].starting_price, "450.00");
  assert.equal(
    (await request("GET", "professionals/?page=invalid")).status,
    400,
  );
});
test("registration hashes passwords and blocks privilege escalation", async () => {
  const body = {
    username: "newperson",
    email: "NEW@example.com",
    password,
    role: "professional",
    first_name: "New",
    last_name: "Person",
    is_staff: true,
    verified: true,
  };
  const r = await request("POST", "auth/register/", body);
  assert.equal(r.status, 201);
  assert.equal(r.data.is_staff, false);
  assert.equal(r.data.email, "new@example.com");
  const row = await db.one("SELECT * FROM users WHERE id=?", [r.data.id]);
  assert.notEqual(row.password, password);
  assert.ok(row.password.startsWith("scrypt$"));
  assert.equal(
    (
      await request("POST", "auth/register/", {
        ...body,
        username: "other",
        role: "admin",
      })
    ).status,
    400,
  );
  assert.equal(
    (
      await request("POST", "auth/register/", {
        ...body,
        username: "other",
        password: "password",
      })
    ).status,
    400,
  );
  assert.equal(
    (await request("POST", "auth/register/", { ...body, username: "other" }))
      .status,
    400,
  );
});
test("account updates cannot change role or staff flags", async () => {
  const r = await request(
    "PATCH",
    "me/",
    {
      role: "professional",
      is_staff: true,
      email_verified: true,
      first_name: "Changed",
    },
    world.customerToken,
  );
  assert.equal(r.data.role, "customer");
  assert.equal(r.data.is_staff, false);
  assert.equal(r.data.email_verified, false);
  assert.equal(r.data.first_name, "Changed");
});
test("refresh tokens rotate, reject replay and revoke on logout", async () => {
  const pair = await login();
  const rotated = await request("POST", "auth/refresh/", {
    refresh: pair.refresh,
  });
  assert.equal(rotated.status, 200);
  assert.equal(
    (await request("POST", "auth/refresh/", { refresh: pair.refresh })).status,
    401,
  );
  await request("POST", "auth/logout/", { refresh: rotated.data.refresh });
  assert.equal(
    (await request("POST", "auth/refresh/", { refresh: rotated.data.refresh }))
      .status,
    401,
  );
});
test("concurrent refresh has one winner", async () => {
  const pair = await login();
  const results = await Promise.all([
    request("POST", "auth/refresh/", { refresh: pair.refresh }),
    request("POST", "auth/refresh/", { refresh: pair.refresh }),
  ]);
  assert.deepEqual(results.map((r) => r.status).sort(), [200, 401]);
});
test("recovery hides account existence, stores hashed codes and revokes sessions", async () => {
  const pair = await login();
  const known = await request("POST", "auth/password-reset/", {
    email: world.customer.email,
  });
  const unknown = await request("POST", "auth/password-reset/", {
    email: "unknown@example.com",
  });
  assert.deepEqual(known.data, unknown.data);
  assert.ok(!JSON.stringify(known.data).includes(emails[0].code));
  assert.notEqual(
    (await db.one("SELECT code_hash FROM challenges")).code_hash,
    emails[0].code,
  );
  const body = {
    email: world.customer.email,
    code: emails[0].code,
    new_password: "DifferentSafe2026!",
  };
  assert.equal(
    (await request("POST", "auth/password-reset/confirm/", body)).status,
    200,
  );
  assert.equal((await request("GET", "me/", null, pair.access)).status, 401);
  assert.equal(
    (await request("POST", "auth/refresh/", { refresh: pair.refresh })).status,
    401,
  );
  assert.equal(
    (await request("POST", "auth/password-reset/confirm/", body)).status,
    400,
  );
});
test("codes expire, lock at five incorrect attempts and resends invalidate earlier codes", async () => {
  await request("POST", "auth/password-reset/", {
    email: world.customer.email,
  });
  const initial = emails.at(-1).code;
  await request("POST", "auth/password-reset/", {
    email: world.customer.email,
  });
  assert.equal(
    (
      await request("POST", "auth/password-reset/confirm/", {
        email: world.customer.email,
        code: initial,
        new_password: "DifferentSafe2026!",
      })
    ).status,
    400,
  );
  const actual = emails.at(-1).code,
    wrong = actual === "11111111" ? "22222222" : "11111111";
  for (let n = 0; n < 4; n++)
    await request("POST", "auth/password-reset/confirm/", {
      email: world.customer.email,
      code: wrong,
      new_password: "DifferentSafe2026!",
    });
  assert.equal(
    (
      await request("POST", "auth/password-reset/confirm/", {
        email: world.customer.email,
        code: actual,
        new_password: "DifferentSafe2026!",
      })
    ).status,
    400,
  );
  await request("POST", "auth/password-reset/", {
    email: world.customer.email,
  });
  await db.query("UPDATE challenges SET expires_at='2000-01-01T00:00:00.000Z'");
  assert.equal(
    (
      await request("POST", "auth/password-reset/confirm/", {
        email: world.customer.email,
        code: emails.at(-1).code,
        new_password: "DifferentSafe2026!",
      })
    ).status,
    400,
  );
});
test("email verification clears on email change and invalidates old challenges", async () => {
  await request("POST", "auth/email-verification/", {}, world.customerToken);
  const code = emails.at(-1).code;
  assert.equal(
    (
      await request(
        "POST",
        "auth/email-verification/confirm/",
        { code },
        world.customerToken,
      )
    ).status,
    200,
  );
  assert.equal(
    (await request("GET", "me/", null, world.customerToken)).data
      .email_verified,
    true,
  );
  await request(
    "PATCH",
    "me/",
    { email: "changed@example.com" },
    world.customerToken,
  );
  assert.equal(
    (await request("GET", "me/", null, world.customerToken)).data
      .email_verified,
    false,
  );
  assert.equal(
    (
      await request(
        "POST",
        "auth/email-verification/confirm/",
        { code },
        world.customerToken,
      )
    ).status,
    400,
  );
});
test("customer booking lifecycle and exactly one completed-booking review", async () => {
  const b = await booking();
  assert.equal(
    (
      await request(
        "POST",
        `bookings/${b.id}/status/`,
        { status: "accepted" },
        world.customerToken,
      )
    ).status,
    400,
  );
  assert.equal(
    (
      await request(
        "POST",
        "reviews/",
        { booking: b.id, rating: 5, comment: "Good" },
        world.customerToken,
      )
    ).status,
    400,
  );
  await request(
    "POST",
    `bookings/${b.id}/status/`,
    { status: "accepted" },
    world.proToken,
  );
  await request(
    "POST",
    `bookings/${b.id}/status/`,
    { status: "completed" },
    world.proToken,
  );
  assert.equal(
    (
      await request(
        "POST",
        "reviews/",
        { booking: b.id, rating: 5, comment: "Good" },
        world.customerToken,
      )
    ).status,
    201,
  );
  assert.equal(
    (
      await request(
        "POST",
        "reviews/",
        { booking: b.id, rating: 4, comment: "Again" },
        world.customerToken,
      )
    ).status,
    400,
  );
  assert.equal(
    (await request("GET", `bookings/${b.id}/`, null, world.customerToken)).data
      .review.rating,
    5,
  );
});
test("booking privacy and role enforcement", async () => {
  const b = await booking();
  assert.equal(
    (await request("GET", `bookings/${b.id}/`, null, world.strangerToken))
      .status,
    404,
  );
  assert.equal(
    (await request("POST", "bookings/", bookingBody(), world.proToken)).status,
    403,
  );
  assert.equal((await request("POST", "bookings/", bookingBody())).status, 401);
  assert.equal(
    (await request("GET", "bookings/", null, world.strangerToken)).data.count,
    0,
  );
});
test("concurrent overlapping bookings cannot both succeed", async () => {
  const requests = await Promise.all([
    request("POST", "bookings/", bookingBody(), world.customerToken),
    request("POST", "bookings/", bookingBody(), world.customerToken),
  ]);
  assert.deepEqual(requests.map((r) => r.status).sort(), [201, 400]);
});
test("cancellation releases reservations and invalid duration/time/service rejected", async () => {
  const b = await booking();
  assert.equal(
    (await request("POST", "bookings/", bookingBody(), world.customerToken))
      .status,
    400,
  );
  await request(
    "POST",
    `bookings/${b.id}/status/`,
    { status: "cancelled" },
    world.customerToken,
  );
  assert.equal(
    (await request("POST", "bookings/", bookingBody(), world.customerToken))
      .status,
    201,
  );
  for (const changes of [
    { duration_minutes: 10 },
    { scheduled_at: "2000-01-01T10:00:00Z" },
    { scheduled_at: "2028-01-01T10:00:00" },
    { area: 999 },
    { category: 999 },
  ])
    assert.equal(
      (
        await request(
          "POST",
          "bookings/",
          { ...bookingBody(), ...changes },
          world.customerToken,
        )
      ).status,
      400,
    );
});
test("published slots enforce duration, ownership, overlap and booking history", async () => {
  const starts_at = future(4),
    ends_at = new Date(Date.parse(starts_at) + 3600000).toISOString();
  const slot = await request(
    "POST",
    "slots/",
    { starts_at, ends_at },
    world.proToken,
  );
  assert.equal(slot.status, 201);
  assert.equal(
    (
      await request(
        "POST",
        "slots/",
        { starts_at, ends_at },
        world.customerToken,
      )
    ).status,
    403,
  );
  assert.equal(
    (await request("POST", "slots/", { starts_at, ends_at }, world.proToken))
      .status,
    400,
  );
  await request(
    "PATCH",
    "profile/",
    { schedule_enabled: true },
    world.proToken,
  );
  assert.equal(
    (await request("POST", "bookings/", bookingBody(), world.customerToken))
      .status,
    400,
  );
  const b = await request(
    "POST",
    "bookings/",
    { ...bookingBody(), scheduled_at: starts_at, slot: slot.data.id },
    world.customerToken,
  );
  assert.equal(b.status, 201);
  assert.equal(
    (await request("GET", `professionals/${world.pro.id}/availability/`)).data
      .slots.length,
    0,
  );
  await request(
    "POST",
    `bookings/${b.data.id}/status/`,
    { status: "cancelled" },
    world.customerToken,
  );
  assert.equal(
    (await request("GET", `professionals/${world.pro.id}/availability/`)).data
      .slots.length,
    1,
  );
  assert.equal(
    (await request("DELETE", `slots/${slot.data.id}/`, null, world.proToken))
      .status,
    400,
  );
});
test("quotation replies, stale revisions, snapshot pricing and replay acceptance", async () => {
  const q = await quote();
  assert.equal(
    (
      await request(
        "POST",
        `quotes/${q.id}/reply/`,
        { amount: "700", response: "Labour" },
        world.customerToken,
      )
    ).status,
    403,
  );
  const estimate = await request(
    "POST",
    `quotes/${q.id}/reply/`,
    { amount: "700", response: "Labour" },
    world.proToken,
  );
  assert.equal(
    (
      await request(
        "POST",
        `quotes/${q.id}/accept/`,
        { ...bookingBody(), quote_revision: 0 },
        world.customerToken,
      )
    ).status,
    400,
  );
  const accepted = await request(
    "POST",
    `quotes/${q.id}/accept/`,
    {
      ...bookingBody(),
      quote_revision: estimate.data.revision,
      agreed_price: "1",
      details: "Tampered",
    },
    world.customerToken,
  );
  assert.equal(accepted.data.agreed_price, "700.00");
  assert.equal(accepted.data.agreed_terms, "Labour");
  assert.equal(accepted.data.details, q.details);
  const again = await request(
    "POST",
    `quotes/${q.id}/accept/`,
    { quote_revision: estimate.data.revision },
    world.customerToken,
  );
  assert.equal(again.data.id, accepted.data.id);
  assert.equal(
    (
      await request(
        "POST",
        `quotes/${q.id}/reply/`,
        { amount: "900", response: "Changed" },
        world.proToken,
      )
    ).status,
    400,
  );
});
test("quotation unanswered acceptance and foreign access rejected", async () => {
  const q = await quote();
  assert.equal(
    (
      await request(
        "POST",
        `quotes/${q.id}/accept/`,
        { ...bookingBody(), quote_revision: 0 },
        world.customerToken,
      )
    ).status,
    400,
  );
  assert.equal(
    (await request("GET", `quotes/${q.id}/`, null, world.strangerToken)).status,
    404,
  );
});
for (const kind of ["bookings", "quotes"])
  test(`${kind} messages are private and receipts are bounded`, async () => {
    const parent = kind === "bookings" ? await booking() : await quote(),
      path = `${kind}/${parent.id}/messages/`;
    const first = await request(
      "POST",
      path,
      { body: "Hello" },
      world.customerToken,
    );
    assert.equal(first.status, 201);
    await request("POST", path, { body: "Second" }, world.customerToken);
    assert.equal(
      (await request("GET", path, null, world.strangerToken)).status,
      404,
    );
    await request(
      "POST",
      `${path}read/`,
      { through_id: first.data.id },
      world.proToken,
    );
    const list = (await request("GET", path, null, world.proToken)).data
      .results;
    assert.equal(list[0].read_at, null);
    assert.ok(list[1].read_at);
    assert.equal(
      (await request("POST", path, { body: "x".repeat(2001) }, world.proToken))
        .status,
      400,
    );
  });
test("profile ownership, verification privilege, valid coordinates and catalogue links", async () => {
  const r = await request(
    "PATCH",
    "profile/",
    {
      business_name: "Changed",
      verified: true,
      category_ids: [world.category.id],
      area_ids: [world.area.id],
    },
    world.proToken,
  );
  assert.equal(r.status, 200);
  assert.equal(r.data.verified, false);
  assert.equal(r.data.categories[0].id, world.category.id);
  assert.equal(
    (await request("GET", "profile/", null, world.customerToken)).status,
    403,
  );
  assert.equal(
    (
      await request(
        "PATCH",
        "profile/",
        { latitude: null, longitude: 90 },
        world.proToken,
      )
    ).status,
    400,
  );
  await request("PATCH", "profile/", { available: false }, world.proToken);
  assert.equal(
    (await request("POST", "quotes/", bookingBody(), world.customerToken))
      .status,
    400,
  );
});
test("image upload validates content, serves media and restricts owner deletion", async () => {
  const image = await sharp({
    create: { width: 4, height: 4, channels: 3, background: "#2358d5" },
  })
    .png()
    .toBuffer();
  const form = new FormData();
  form.set("title", "New project");
  form.set("description", "Sample");
  form.set("image", new Blob([image], { type: "image/png" }), "sample.png");
  const response = await fetch(`${origin}/api/portfolio/`, {
    method: "POST",
    headers: { Authorization: `Bearer ${world.proToken}` },
    body: form,
  });
  assert.equal(response.status, 201);
  const row = await response.json();
  assert.ok(row.image.includes("/media/portfolio/"));
  assert.equal((await fetch(row.image)).status, 200);
  assert.equal(
    (await request("DELETE", `portfolio/${row.id}/`, null, world.customerToken))
      .status,
    403,
  );
  assert.equal(
    (await request("DELETE", `portfolio/${row.id}/`, null, world.proToken))
      .status,
    204,
  );
  const bad = new FormData();
  bad.set("title", "Bad");
  bad.set("image", new Blob(["not an image"]), "bad.png");
  assert.equal(
    (
      await fetch(`${origin}/api/portfolio/`, {
        method: "POST",
        headers: { Authorization: `Bearer ${world.proToken}` },
        body: bad,
      })
    ).status,
    400,
  );
});
test("manual promotions snapshot package price, activate once and expire", async () => {
  const p = await purchase();
  assert.equal(p.status, "pending");
  assert.equal(p.price_paid, "300.00");
  await request(
    "PATCH",
    `admin/packages/${world.package.id}/`,
    { price: "900", days: 30 },
    world.staffToken,
  );
  assert.equal(
    (
      await request(
        "POST",
        `admin/promotions/${p.id}/confirm/`,
        { confirm: true },
        world.customerToken,
      )
    ).status,
    403,
  );
  const activated = await request(
    "POST",
    `admin/promotions/${p.id}/confirm/`,
    { confirm: true },
    world.staffToken,
  );
  const replay = await request(
    "POST",
    `admin/promotions/${p.id}/confirm/`,
    { confirm: true },
    world.staffToken,
  );
  assert.equal(activated.data.price_paid, "300.00");
  assert.equal(activated.data.expires_at, replay.data.expires_at);
  const query = `professionals/?category=${world.category.id}&area=${world.area.id}`;
  assert.equal((await request("GET", query)).data.results[0].promoted, true);
  assert.equal(
    (await request("GET", "professionals/")).data.results[0].promoted,
    false,
  );
  await db.query(
    "UPDATE promotions SET expires_at='2000-01-01T00:00:00.000Z' WHERE id=?",
    [p.id],
  );
  assert.equal((await request("GET", query)).data.results[0].promoted, false);
});
test("development-only simulated promotions and production guardrails", async () => {
  config.demoPayments = true;
  assert.equal((await purchase()).status, "paid");
  assert.throws(() => configuration({ NODE_ENV: "production" }), /JWT_SECRET/);
  assert.equal(
    configuration({
      NODE_ENV: "production",
      JWT_SECRET: "x".repeat(50),
      POSTGRES_DB: "test",
      ALLOWED_HOSTS: "example.com",
      DEMO_PAYMENTS: "true",
    }).demoPayments,
    false,
  );
});
test("review moderation changes public search rating and disabled accounts are hidden", async () => {
  const b = await booking();
  await request(
    "POST",
    `bookings/${b.id}/status/`,
    { status: "accepted" },
    world.proToken,
  );
  await request(
    "POST",
    `bookings/${b.id}/status/`,
    { status: "completed" },
    world.proToken,
  );
  const r = await request(
    "POST",
    "reviews/",
    { booking: b.id, rating: 5, comment: "Great" },
    world.customerToken,
  );
  assert.equal(
    (await request("GET", "professionals/?min_rating=4")).data.count,
    1,
  );
  await request(
    "PATCH",
    `admin/reviews/${r.data.id}/`,
    { visible: false },
    world.staffToken,
  );
  assert.equal(
    (await request("GET", "professionals/?min_rating=4")).data.count,
    0,
  );
  await request(
    "PATCH",
    `admin/users/${world.professional.id}/`,
    { is_active: false },
    world.staffToken,
  );
  assert.equal((await request("GET", "professionals/")).data.count, 0);
  assert.equal(
    (await request("GET", "profile/", null, world.proToken)).status,
    401,
  );
});
test("reports, notifications, metrics and administration are scoped", async () => {
  const report = await request(
    "POST",
    "reports/",
    { professional: world.pro.id, reason: "Concern" },
    world.customerToken,
  );
  assert.equal(
    (await request("GET", "reports/", null, world.strangerToken)).data.count,
    0,
  );
  await request(
    "PATCH",
    `admin/reports/${report.data.id}/`,
    { resolved: true, resolution: "Handled" },
    world.staffToken,
  );
  assert.equal(
    (await request("GET", "reports/", null, world.customerToken)).data
      .results[0].resolved,
    true,
  );
  await booking();
  assert.equal(
    (await request("GET", "analytics/", null, world.customerToken)).data
      .bookings,
    1,
  );
  assert.equal(
    (await request("GET", "notifications/", null, world.strangerToken)).data
      .count,
    0,
  );
  await request("POST", "notifications/read-all/", {}, world.proToken);
  assert.equal(
    (await request("GET", "notifications/", null, world.proToken)).data
      .results[0].read,
    true,
  );
  assert.equal(
    (await request("GET", "admin/users/", null, world.customerToken)).status,
    403,
  );
  const users = (await request("GET", "admin/users/", null, world.staffToken))
    .data.results;
  assert.equal(
    users.some((u) => "password" in u),
    false,
  );
  assert.equal((await fetch(`${origin}/admin/`)).status, 200);
});
test("FCM tokens transfer ownership and deletion stays scoped", async () => {
  const token = "sample-fcm-device-token-12345";
  await request("POST", "devices/", { token }, world.customerToken);
  await request("POST", "devices/", { token }, world.proToken);
  await request("DELETE", "devices/", { token }, world.customerToken);
  assert.equal(
    (await db.one("SELECT * FROM devices")).user_id,
    world.professional.id,
  );
  await request("DELETE", "devices/", { token }, world.proToken);
  assert.equal((await db.all("SELECT * FROM devices")).length, 0);
});
test("push sends each device once, retries failures and removes invalid tokens", async () => {
  await db.transaction(async (tx) => {
    for (const token of ["good", "retry", "invalid"])
      await tx.insert("devices", {
        user_id: world.customer.id,
        token,
        created_at: timestamp(),
      });
    await tx.insert("notifications", {
      user_id: world.customer.id,
      message: "Test",
      created_at: timestamp(),
    });
  });
  const sent = [];
  await deliverPush(db, async (message) => {
    sent.push(message.token);
    if (message.token === "retry") throw new Error("temporary");
    if (message.token === "invalid")
      throw Object.assign(new Error(), {
        code: "messaging/registration-token-not-registered",
      });
  });
  await db.query(
    "UPDATE push_deliveries SET retry_at='2000-01-01T00:00:00.000Z'",
  );
  await deliverPush(db, async (message) => sent.push(message.token));
  assert.deepEqual(sent, ["good", "retry", "invalid", "retry"]);
  assert.equal(
    (await db.one("SELECT push_sent FROM notifications")).push_sent,
    1,
  );
});
test("backed-off push deliveries cannot starve new notifications", async () => {
  await db.transaction(async (tx) => {
    const device = await tx.insert("devices", {
      user_id: world.customer.id,
      token: "waiting-device",
      created_at: timestamp(),
    });
    for (let i = 0; i < 100; i++) {
      const old = await tx.insert("notifications", {
        user_id: world.customer.id,
        message: "Waiting for retry",
        created_at: timestamp(),
      });
      await tx.insert("push_deliveries", {
        notification_id: old.id,
        device_id: device.id,
        attempts: 1,
        retry_at: future(1),
      });
    }
    await tx.insert("notifications", {
      user_id: world.customer.id,
      message: "New update",
      created_at: timestamp(),
    });
  });
  const delivered = [];
  await deliverPush(db, async (message) =>
    delivered.push(message.notification.body),
  );
  assert.deepEqual(delivered, ["New update"]);
});

test("payment checkout uses server amount and reuses a pending session", async () => {
  config.payment = {
    storeId: "test",
    password: "secret",
    sandbox: true,
    callback: "https://api.example.com",
  };
  let calls = 0;
  gateway = async (method, path, sandbox, data) => {
    calls++;
    assert.equal(data.total_amount, "300.00");
    assert.equal(data.currency, "BDT");
    return {
      status: "SUCCESS",
      GatewayPageURL: "https://sandbox.sslcommerz.com/pay",
      sessionkey: "session",
    };
  };
  const p = await purchase();
  const r = await request(
    "POST",
    `promotions/${p.id}/payment/`,
    { amount: "1" },
    world.proToken,
  );
  assert.equal(r.status, 200);
  assert.equal(
    (await request("POST", `promotions/${p.id}/payment/`, {}, world.proToken))
      .data.id,
    r.data.id,
  );
  assert.equal(calls, 1);
});
for (const tampering of [
  { amount: "1.00" },
  { currency: "USD" },
  { tran_id: "wrong" },
  { val_id: "wrong" },
  { status: "FAILED" },
])
  test(`payment tampering cannot activate: ${Object.keys(tampering)[0]}`, async () => {
    config.payment = {
      storeId: "test",
      password: "secret",
      sandbox: true,
      callback: "https://api.example.com",
    };
    const p = await purchase(),
      row = await db.insert("payments", {
        promotion_id: p.id,
        transaction_id: "SCtest",
        amount: "300.00",
        status: "pending",
        sandbox: 1,
        created_at: timestamp(),
      });
    gateway = async () => ({
      tran_id: row.transaction_id,
      val_id: "validated",
      amount: "300.00",
      currency: "BDT",
      status: "VALID",
      risk_level: "0",
      ...tampering,
    });
    assert.equal(
      (
        await request("POST", "payments/ipn/", {
          tran_id: row.transaction_id,
          val_id: "validated",
        })
      ).status,
      400,
    );
    assert.equal(
      (await db.one("SELECT status FROM promotions WHERE id=?", [p.id])).status,
      "pending",
    );
  });
test("validated payment activates once and browser returns cannot activate", async () => {
  config.payment = {
    storeId: "test",
    password: "secret",
    sandbox: true,
    callback: "https://api.example.com",
  };
  const p = await purchase();
  await db.insert("payments", {
    promotion_id: p.id,
    transaction_id: "SCtest",
    amount: "300.00",
    status: "pending",
    sandbox: 1,
    created_at: timestamp(),
  });
  await fetch(`${origin}/api/payments/return/?tran_id=SCtest&status=VALID`);
  assert.equal(
    (await db.one("SELECT status FROM promotions WHERE id=?", [p.id])).status,
    "pending",
  );
  gateway = async () => ({
    tran_id: "SCtest",
    val_id: "validated",
    amount: "300.00",
    currency: "BDT",
    status: "VALID",
    risk_level: "0",
  });
  assert.equal(
    (
      await request("POST", "payments/ipn/", {
        tran_id: "SCtest",
        val_id: "validated",
      })
    ).data.status,
    "paid",
  );
  const expiry = (
    await db.one("SELECT expires_at FROM promotions WHERE id=?", [p.id])
  ).expires_at;
  await request("POST", "payments/ipn/", {
    tran_id: "SCtest",
    val_id: "validated",
  });
  assert.equal(
    (await db.one("SELECT expires_at FROM promotions WHERE id=?", [p.id]))
      .expires_at,
    expiry,
  );
});
test("payment reconciliation and risky/cancelled transactions require review", async () => {
  config.payment = {
    storeId: "test",
    password: "secret",
    sandbox: true,
    callback: "https://api.example.com",
  };
  const p = await purchase();
  await db.insert("payments", {
    promotion_id: p.id,
    transaction_id: "SCtest",
    amount: "300.00",
    status: "pending",
    sandbox: 1,
    created_at: timestamp(),
  });
  gateway = async (method, path) =>
    path.includes("merchantTrans")
      ? {
          element: [
            { tran_id: "SCtest", status: "VALID", val_id: "validated" },
          ],
        }
      : {
          tran_id: "SCtest",
          val_id: "validated",
          amount: "300.00",
          currency: "BDT",
          status: "VALID",
          risk_level: "1",
        };
  assert.equal(
    (await request("GET", `promotions/${p.id}/payment/`, null, world.proToken))
      .data.status,
    "review",
  );
  assert.equal(
    (await db.one("SELECT status FROM promotions WHERE id=?", [p.id])).status,
    "pending",
  );
  await request(
    "POST",
    `admin/promotions/${p.id}/cancel/`,
    {},
    world.staffToken,
  );
  gateway = async () => ({
    tran_id: "SCtest",
    val_id: "validated",
    amount: "300.00",
    currency: "BDT",
    status: "VALID",
    risk_level: "0",
  });
  assert.equal(
    (
      await request("POST", "payments/ipn/", {
        tran_id: "SCtest",
        val_id: "validated",
      })
    ).data.status,
    "review",
  );
});
test("rate limiting persists failed attempts and host allowlists are enforced", async () => {
  config.rateLimit = true;
  for (let n = 0; n < 20; n++)
    assert.equal(
      (await request("POST", "auth/login/", { username: "unknown", password }))
        .status,
      401,
    );
  assert.equal(
    (await request("POST", "auth/login/", { username: "unknown", password }))
      .status,
    429,
  );
  config.hosts = ["allowed.example"];
  assert.equal((await request("GET", "health/")).status, 400);
});
