import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { pbkdf2Sync } from "node:crypto";
import { openDatabase } from "../src/db.js";
import { configuration } from "../src/config.js";
import { importLegacy } from "../src/import-legacy.js";
import { checkPassword } from "../src/auth.js";

test("legacy import preserves accounts/passwords and normalizes timestamps without the retired runtime", async () => {
  const directory = await mkdtemp(path.join(tmpdir(), "skillconnect-import-"));
  const filename = path.join(directory, "old.sqlite3");
  const hash = `pbkdf2_sha256$10000$salt$${pbkdf2Sync("ExistingSafe123!", "salt", 10000, 32, "sha256").toString("base64")}`;
  const source = new DatabaseSync(filename);
  source.exec(
    "CREATE TABLE marketplace_user (id INTEGER PRIMARY KEY,username TEXT,email TEXT,password TEXT,role TEXT,date_joined TEXT);",
  );
  source
    .prepare("INSERT INTO marketplace_user VALUES (?,?,?,?,?,?)")
    .run(
      1,
      "existing",
      "EXISTING@example.com",
      hash,
      "customer",
      "2026-10-01 09:30:00.000000",
    );
  source.close();
  const db = await openDatabase({
    ...configuration({ SQLITE_PATH: ":memory:" }),
    databaseUrl: "",
  });
  await db.migrate();
  try {
    const counts = await importLegacy(db, filename);
    assert.equal(counts.users, 1);
    const user = await db.one("SELECT * FROM users");
    assert.equal(user.email, "existing@example.com");
    assert.equal(user.created_at, "2026-10-01T09:30:00.000Z");
    assert.equal(await checkPassword("ExistingSafe123!", user.password), true);
    await assert.rejects(() => importLegacy(db, filename), /empty database/);
  } finally {
    await db.close();
    await rm(directory, { recursive: true, force: true });
  }
});
