import test from "node:test";
import assert from "node:assert/strict";
import { configuration } from "../src/config.js";
import { openDatabase } from "../src/db.js";
import { initializeCatalogue } from "../src/catalogue.js";

async function testDatabase() {
  const db = await openDatabase({
    ...configuration({ NODE_ENV: "test", SQLITE_PATH: ":memory:" }),
    databaseUrl: process.env.TEST_DATABASE_URL || "",
  });
  await db.migrate();
  if (db.postgres) {
    await db.query(
      "TRUNCATE users,categories,areas,packages RESTART IDENTITY CASCADE",
    );
    await db.query("DELETE FROM schema_migrations WHERE version=2");
  }
  return db;
}

test("a fresh database gets usable reference data without sample accounts", async () => {
  const db = await testDatabase();
  try {
    await db.migrate();
    await initializeCatalogue(db);
    assert.equal((await db.all("SELECT * FROM categories")).length, 8);
    assert.equal((await db.all("SELECT * FROM areas")).length, 3);
    assert.equal((await db.all("SELECT * FROM packages")).length, 4);
    for (const table of [
      "users",
      "professionals",
      "bookings",
      "reviews",
      "promotions",
    ])
      assert.equal((await db.all(`SELECT * FROM ${table}`)).length, 0);
    // An administrator can remove a reference entry without startup restoring it.
    await db.query("DELETE FROM categories WHERE name=?", ["Cleaner"]);
    await initializeCatalogue(db);
    assert.equal((await db.all("SELECT * FROM categories")).length, 7);
  } finally {
    await db.close();
  }
});

test("catalogue initialization preserves administrator data and fills missing tables", async () => {
  const db = await testDatabase();
  try {
    await db.migrate();
    await db.insert("categories", { name: "Custom service", icon: "work" });
    await db.insert("packages", {
      name: "Custom package",
      days: 10,
      price: "1250.00",
    });
    await initializeCatalogue(db);
    assert.deepEqual(
      (await db.all("SELECT name FROM categories")).map((c) => c.name),
      ["Custom service"],
    );
    assert.deepEqual(
      (await db.all("SELECT name FROM packages")).map((p) => p.name),
      ["Custom package"],
    );
    assert.equal((await db.all("SELECT * FROM areas")).length, 3);
  } finally {
    await db.close();
  }
});
