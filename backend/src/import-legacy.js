import { DatabaseSync } from "node:sqlite";
import { amount } from "./validation.js";

// Read-only import of the retired SQLite data. No old runtime is needed.
export async function importLegacy(db, filename) {
  const source = new DatabaseSync(filename, { readOnly: true });
  const names = new Set(
    source
      .prepare("SELECT name FROM sqlite_master WHERE type='table'")
      .all()
      .map((r) => r.name),
  );
  const rows = (table) =>
    names.has(table) ? source.prepare(`SELECT * FROM ${table}`).all() : [];
  const iso = (value) => {
    if (value == null) return null;
    const normalized = String(value).replace(" ", "T");
    return new Date(
      /[Zz]|[+-]\d\d:\d\d$/.test(normalized) ? normalized : `${normalized}Z`,
    ).toISOString();
  };
  const timeKeys = new Set([
    "created_at",
    "updated_at",
    "scheduled_at",
    "starts_at",
    "ends_at",
    "expires_at",
    "read_at",
    "sent_at",
    "retry_at",
  ]);
  const moneyKeys = new Set([
    "starting_price",
    "amount",
    "price",
    "price_paid",
    "agreed_price",
  ]);
  const counts = {};
  const mappings = [
    [
      "users",
      "marketplace_user",
      [
        "id",
        "username",
        "email",
        "password",
        "first_name",
        "last_name",
        "phone",
        "role",
        "is_staff",
        "is_active",
        "email_verified",
        "session_version",
      ],
      { created_at: "date_joined" },
    ],
    ["categories", "marketplace_category", ["id", "name", "icon", "active"]],
    [
      "areas",
      "marketplace_area",
      ["id", "name", "city", "latitude", "longitude"],
    ],
    [
      "professionals",
      "marketplace_professional",
      [
        "id",
        "user_id",
        "business_name",
        "bio",
        "skills",
        "experience_years",
        "available",
        "schedule_enabled",
        "verified",
        "starting_price",
        "latitude",
        "longitude",
        "created_at",
      ],
    ],
    [
      "professional_categories",
      "marketplace_professional_categories",
      ["professional_id", "category_id"],
    ],
    [
      "professional_areas",
      "marketplace_professional_areas",
      ["professional_id", "area_id"],
    ],
    [
      "portfolio",
      "marketplace_portfolio",
      ["id", "professional_id", "title", "description", "image"],
    ],
    [
      "slots",
      "marketplace_availabilityslot",
      ["id", "professional_id", "starts_at", "ends_at"],
    ],
    [
      "quotes",
      "marketplace_quote",
      [
        "id",
        "customer_id",
        "professional_id",
        "category_id",
        "area_id",
        "details",
        "amount",
        "response",
        "revision",
        "created_at",
      ],
    ],
    [
      "bookings",
      "marketplace_booking",
      [
        "id",
        "customer_id",
        "professional_id",
        "category_id",
        "area_id",
        "scheduled_at",
        "duration_minutes",
        "slot_id",
        "quote_id",
        "agreed_price",
        "agreed_terms",
        "address",
        "details",
        "status",
        "created_at",
        "updated_at",
      ],
    ],
    [
      "reviews",
      "marketplace_review",
      ["id", "booking_id", "rating", "comment", "visible", "created_at"],
    ],
    [
      "packages",
      "marketplace_promotionpackage",
      ["id", "name", "days", "price", "active"],
    ],
    [
      "promotions",
      "marketplace_promotion",
      [
        "id",
        "professional_id",
        "package_id",
        "category_id",
        "area_id",
        "price_paid",
        "duration_days",
        "status",
        "starts_at",
        "expires_at",
        "created_at",
      ],
    ],
    [
      "notifications",
      "marketplace_notification",
      ["id", "user_id", "message", "read", "push_sent", "created_at"],
    ],
    [
      "reports",
      "marketplace_report",
      [
        "id",
        "reporter_id",
        "professional_id",
        "reason",
        "resolved",
        "resolution",
        "created_at",
      ],
    ],
    ["devices", "marketplace_device", ["id", "user_id", "token", "created_at"]],
    [
      "messages",
      "marketplace_message",
      [
        "id",
        "booking_id",
        "quote_id",
        "sender_id",
        "body",
        "read_at",
        "created_at",
      ],
    ],
    [
      "payments",
      "marketplace_payment",
      [
        "id",
        "promotion_id",
        "transaction_id",
        "amount",
        "status",
        "gateway_url",
        "session_key",
        "validation_id",
        "sandbox",
        "created_at",
      ],
    ],
    [
      "push_deliveries",
      "marketplace_pushdelivery",
      ["id", "notification_id", "device_id", "sent_at", "attempts", "retry_at"],
    ],
  ];
  try {
    if (!names.has("marketplace_user"))
      throw new Error("This is not a supported legacy SkillConnect database.");
    await db.transaction(async (tx) => {
      if (Number((await tx.one("SELECT COUNT(*) AS count FROM users")).count))
        throw new Error("Import only into an empty database.");
      for (const [target, table, keys, aliases = {}] of mappings) {
        const list = rows(table);
        counts[target] = list.length;
        for (const row of list) {
          const values = {};
          for (const key of [...keys, ...Object.keys(aliases)]) {
            let value = row[aliases[key] || key];
            if (value === undefined) continue;
            if (timeKeys.has(key)) value = iso(value);
            if (moneyKeys.has(key) && value != null) value = amount(value);
            if (key === "email") value = String(value).toLowerCase();
            values[key] = value;
          }
          await tx.insert(target, values);
        }
        if (tx.postgres && keys.includes("id"))
          await tx.query(
            `SELECT setval(pg_get_serial_sequence('${target}','id'), COALESCE((SELECT MAX(id) FROM ${target}),1), EXISTS(SELECT 1 FROM ${target}))`,
          );
      }
    });
  } finally {
    source.close();
  }
  return counts;
}
