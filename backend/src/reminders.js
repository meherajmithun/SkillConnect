import { timestamp } from "./validation.js";

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;

/** Add one-day and one-hour in-app reminders for accepted upcoming bookings. */
export async function deliverBookingReminders(db, now = new Date()) {
  const current = now.toISOString();
  const dayLimit = new Date(now.getTime() + DAY).toISOString();
  const bookings = await db.read((tx) =>
    tx.all(
      "SELECT * FROM bookings WHERE status='accepted' AND scheduled_at>? AND scheduled_at<=? ORDER BY scheduled_at LIMIT 500",
      [current, dayLimit],
    ),
  );
  let delivered = 0;

  for (const booking of bookings) {
    const start = Date.parse(booking.scheduled_at);
    const types = [];
    if (start <= now.getTime() + HOUR) types.push("hour");
    else if (start <= now.getTime() + DAY) types.push("day");

    for (const type of types) {
      const created = await db.transaction(async (tx) => {
        const currentBooking = await tx.one(
          "SELECT * FROM bookings WHERE id=?",
          [booking.id],
        );
        if (
          !currentBooking ||
          currentBooking.status !== "accepted" ||
          currentBooking.scheduled_at !== booking.scheduled_at ||
          Date.parse(currentBooking.scheduled_at) <= now.getTime()
        )
          return false;

        const result = await tx.query(
          "INSERT INTO booking_reminders (booking_id,scheduled_at,reminder_type,created_at) VALUES (?,?,?,?) ON CONFLICT(booking_id,scheduled_at,reminder_type) DO NOTHING",
          [booking.id, booking.scheduled_at, type, timestamp()],
        );
        if (!result.rowCount) return false;

        const pro = await tx.one(
          "SELECT user_id FROM professionals WHERE id=?",
          [booking.professional_id],
        );
        const message =
          type === "day"
            ? `Your booking #${booking.id} is coming up within 24 hours. Open Activity to see the time.`
            : `Your booking #${booking.id} starts in about an hour. Open Activity for details.`;
        for (const userId of [booking.customer_id, pro.user_id])
          await tx.insert("notifications", {
            user_id: userId,
            message,
            created_at: timestamp(),
          });
        return true;
      });
      if (created) delivered++;
    }
  }
  return delivered;
}
