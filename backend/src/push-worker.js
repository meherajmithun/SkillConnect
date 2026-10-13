import { readFile } from "node:fs/promises";
import { setTimeout as delay } from "node:timers/promises";
import { pathToFileURL } from "node:url";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { configuration } from "./config.js";
import { openDatabase } from "./db.js";
import { timestamp } from "./validation.js";

export async function deliverPush(db, send) {
  const queue = await db.read((tx) =>
    tx.all(
      `SELECT n.* FROM notifications n WHERE n.push_sent=0 AND (
        NOT EXISTS (SELECT 1 FROM devices d JOIN push_deliveries p ON p.device_id=d.id
          WHERE p.notification_id=n.id AND d.user_id=n.user_id AND p.sent_at IS NULL)
        OR EXISTS (SELECT 1 FROM devices d LEFT JOIN push_deliveries p
          ON p.device_id=d.id AND p.notification_id=n.id WHERE d.user_id=n.user_id
          AND (p.id IS NULL OR (p.sent_at IS NULL AND p.retry_at<=?)))
      ) ORDER BY n.id LIMIT 100`,
      [timestamp()],
    ),
  );
  let processed = 0;
  for (const item of queue) {
    const devices = await db.read((tx) =>
      tx.all("SELECT * FROM devices WHERE user_id=?", [item.user_id]),
    );
    for (const device of devices) {
      const delivery = await db.transaction(async (tx) => {
        await tx.query(
          "INSERT INTO push_deliveries (notification_id,device_id,retry_at) VALUES (?,?,?) ON CONFLICT(notification_id,device_id) DO NOTHING",
          [item.id, device.id, timestamp()],
        );
        return tx.one(
          "SELECT * FROM push_deliveries WHERE notification_id=? AND device_id=?",
          [item.id, device.id],
        );
      });
      if (delivery.sent_at || delivery.retry_at > timestamp()) continue;
      const owner = await db.read((tx) =>
        tx.one("SELECT user_id FROM devices WHERE id=?", [device.id]),
      );
      if (owner?.user_id !== item.user_id) continue;
      try {
        await send({
          token: device.token,
          notification: { title: "SkillConnect", body: item.message },
          android: { priority: "high" },
          data: {
            notification_id: String(item.id),
            user_id: String(item.user_id),
          },
        });
        await db.transaction((tx) =>
          tx.update("push_deliveries", delivery.id, { sent_at: timestamp() }),
        );
      } catch (error) {
        if (error.code === "messaging/registration-token-not-registered")
          await db.transaction((tx) =>
            tx.query("DELETE FROM devices WHERE id=?", [device.id]),
          );
        else
          await db.transaction((tx) =>
            tx.update("push_deliveries", delivery.id, {
              attempts: delivery.attempts + 1,
              retry_at: new Date(
                Date.now() +
                  Math.min(
                    3600000,
                    30000 * 2 ** Math.min(delivery.attempts + 1, 7),
                  ),
              ).toISOString(),
            }),
          );
      }
    }
    await db.transaction(async (tx) => {
      const pending = await tx.one(
        "SELECT pd.id FROM push_deliveries pd JOIN devices d ON d.id=pd.device_id WHERE pd.notification_id=? AND d.user_id=? AND pd.sent_at IS NULL LIMIT 1",
        [item.id, item.user_id],
      );
      if (!pending) {
        await tx.update("notifications", item.id, { push_sent: 1 });
        processed++;
      }
    });
  }
  return processed;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const config = configuration();
  if (!config.firebaseCredentials)
    throw new Error("Set FIREBASE_CREDENTIALS to a service-account JSON file.");
  const credentials = JSON.parse(
    await readFile(config.firebaseCredentials, "utf8"),
  );
  if (!getApps().length) initializeApp({ credential: cert(credentials) });
  const db = await openDatabase(config);
  await db.migrate();
  const watch = process.argv.includes("--watch");
  const intervalFlag = process.argv.indexOf("--interval");
  const interval =
    intervalFlag >= 0 ? Number(process.argv[intervalFlag + 1]) : 30;
  if (!Number.isFinite(interval) || interval < 5)
    throw new Error("Use an interval of at least 5 seconds.");
  const abort = new AbortController();
  process.on("SIGINT", () => abort.abort());
  process.on("SIGTERM", () => abort.abort());
  try {
    do {
      console.log(
        `Processed ${await deliverPush(db, (value) => getMessaging().send(value))} notifications. Delivery is at least once.`,
      );
      if (watch)
        await delay(interval * 1000, undefined, { signal: abort.signal });
    } while (watch && !abort.signal.aborted);
  } catch (error) {
    if (error.name !== "AbortError") throw error;
  } finally {
    await db.close();
  }
}
