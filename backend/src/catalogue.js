import { timestamp } from "./validation.js";

// Reference data is needed by real accounts. This creates no demo users,
// professionals, bookings, reviews, or payments.
export async function initializeCatalogue(db) {
  return db.transaction(async (tx) => {
    if (await tx.one("SELECT version FROM schema_migrations WHERE version=2"))
      return;
    if (!(await tx.one("SELECT id FROM categories LIMIT 1"))) {
      for (const [name, icon] of [
        ["Electrician", "bolt"],
        ["Web Developer", "code"],
        ["Cleaner", "cleaning_services"],
        ["Graphic Designer", "palette"],
        ["AC Technician", "ac_unit"],
        ["Carpenter", "handyman"],
        ["App Developer", "phone_android"],
        ["Computer Technician", "computer"],
      ])
        await tx.insert("categories", { name, icon });
    }
    if (!(await tx.one("SELECT id FROM areas LIMIT 1"))) {
      for (const [name, latitude, longitude] of [
        ["Mirpur", 23.8223, 90.3654],
        ["Dhanmondi", 23.7461, 90.3742],
        ["Uttara", 23.8759, 90.3795],
      ])
        await tx.insert("areas", { name, city: "Dhaka", latitude, longitude });
    }
    if (!(await tx.one("SELECT id FROM packages LIMIT 1"))) {
      for (const [name, days, price] of [
        ["Starter", 1, "100.00"],
        ["Weekly", 7, "300.00"],
        ["Half month", 15, "500.00"],
        ["Monthly", 30, "800.00"],
      ])
        await tx.insert("packages", { name, days, price });
    }
    await tx.insert("schema_migrations", {
      version: 2,
      applied_at: timestamp(),
    });
  });
}
