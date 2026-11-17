import { configuration } from "./config.js";
import { openDatabase } from "./db.js";
import { createApp } from "./app.js";
import { initializeCatalogue } from "./catalogue.js";
import { deliverBookingReminders } from "./reminders.js";

const config = configuration();
const db = await openDatabase(config);
await db.migrate();
await initializeCatalogue(db);
const server = createApp(db, config).listen(config.port, config.host, () =>
  console.log(
    `SkillConnect Node.js API listening on ${config.host}:${config.port}`,
  ),
);
const sendReminders = async () => {
  try {
    const count = await deliverBookingReminders(db);
    if (count) console.log(`Created ${count} booking reminders.`);
  } catch (error) {
    console.error("Booking reminder task failed:", error.code || error.name);
  }
};
void sendReminders();
const reminderTimer = setInterval(sendReminders, 60_000);
reminderTimer.unref();
let closing = false;
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => {
    if (closing) return;
    closing = true;
    clearInterval(reminderTimer);
    server.close(async () => {
      await db.close();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  });
