import path from "node:path";
import { configuration, backendRoot } from "./config.js";
import { openDatabase } from "./db.js";
import { seedDemo } from "./seed.js";
import { importLegacy } from "./import-legacy.js";
import { hashPassword, validatePassword } from "./auth.js";
import { email, text, timestamp } from "./validation.js";

const command = process.argv[2],
  config = configuration(),
  db = await openDatabase(config);
try {
  await db.migrate();
  if (command === "migrate")
    console.log("JavaScript database schema is ready.");
  else if (command === "seed") {
    await seedDemo(db, process.env.DEMO_PASSWORD);
    console.log(
      "Demo accounts and catalogue seeded. Existing accounts were preserved.",
    );
  } else if (command === "admin") {
    const username = text(
      process.env.ADMIN_USERNAME || "admin",
      "admin username",
      150,
    );
    const address = email(process.env.ADMIN_EMAIL),
      password = validatePassword(process.env.ADMIN_PASSWORD, {
        username,
        email: address,
      });
    const hash = await hashPassword(password);
    await db.transaction(async (tx) => {
      const existing = await tx.one("SELECT * FROM users WHERE username=?", [
        username,
      ]);
      if (existing) {
        await tx.update("users", existing.id, {
          email: address,
          password: hash,
          is_staff: 1,
          is_active: 1,
          session_version: existing.session_version + 1,
        });
        await tx.query(
          "UPDATE refresh_sessions SET revoked=1 WHERE user_id=?",
          [existing.id],
        );
      } else
        await tx.insert("users", {
          username,
          email: address,
          password: hash,
          role: "customer",
          is_staff: 1,
          is_active: 1,
          created_at: timestamp(),
        });
    });
    console.log("Administrator account is ready. Sign in at /admin/.");
  } else if (command === "import-legacy") {
    const filename = process.argv[3] || path.join(backendRoot, "db.sqlite3");
    const counts = await importLegacy(db, filename);
    console.log(
      "Imported local data into the JavaScript backend:",
      JSON.stringify(counts),
    );
    console.log(
      "Old sessions and recovery codes were not imported. Sign in again using your existing password.",
    );
  } else throw new Error("Use migrate, seed, admin or import-legacy.");
} finally {
  await db.close();
}
