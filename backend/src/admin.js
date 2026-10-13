import {
  reject,
  text,
  integer,
  bool,
  amount,
  find,
  publicUser,
} from "./validation.js";
import {
  activatePromotion,
  presentedPromotion,
  presentedRequest,
} from "./marketplace.js";

const resources = [
  "users",
  "professionals",
  "categories",
  "areas",
  "bookings",
  "quotes",
  "reviews",
  "promotions",
  "packages",
  "reports",
];
function values(resource, body) {
  const result = {};
  if (resource === "users") {
    if ("is_active" in body)
      result.is_active = bool(body.is_active, "account active");
  }
  if (resource === "professionals") {
    if ("verified" in body)
      result.verified = bool(body.verified, "verification");
  }
  if (resource === "reviews") {
    if ("visible" in body)
      result.visible = bool(body.visible, "review visibility");
  }
  if (resource === "reports") {
    if ("resolved" in body)
      result.resolved = bool(body.resolved, "report resolution");
    if ("resolution" in body)
      result.resolution = text(body.resolution, "resolution", 2000, true);
  }
  if (["categories", "areas", "packages"].includes(resource)) {
    if ("name" in body) result.name = text(body.name, "name", 80);
    if ("active" in body && resource !== "areas")
      result.active = bool(body.active, "active");
  }
  if (resource === "categories" && "icon" in body)
    result.icon = text(body.icon, "icon", 40);
  if (resource === "packages") {
    if ("price" in body) result.price = amount(body.price, 1);
    if ("days" in body)
      result.days = integer(body.days, "duration days", 1, 365);
  }
  if (resource === "areas") {
    if ("city" in body) result.city = text(body.city, "city", 80);
    for (const [key, max] of [
      ["latitude", 90],
      ["longitude", 180],
    ])
      if (key in body) {
        if (
          typeof body[key] !== "number" ||
          !Number.isFinite(body[key]) ||
          Math.abs(body[key]) > max
        )
          reject(`Use a valid ${key}.`);
        result[key] = body[key];
      }
  }
  return result;
}
export function adminRoutes(app, db, config, auth) {
  const guard = [auth.authenticate, auth.staff];
  app.get("/api/admin/:resource/", ...guard, async (req, res) => {
    const resource = req.params.resource;
    if (!resources.includes(resource)) reject("Not found.", 404);
    const rows = await db.read(async (tx) => {
      const list = await tx.all(`SELECT * FROM ${resource} ORDER BY id DESC`);
      if (resource === "users")
        return list.map((row) => ({
          ...publicUser(row),
          is_active: Boolean(row.is_active),
        }));
      if (resource === "bookings" || resource === "quotes")
        return Promise.all(
          list.map((row) => presentedRequest(tx, resource, row)),
        );
      if (resource === "promotions")
        return Promise.all(list.map((row) => presentedPromotion(tx, row)));
      return list;
    });
    res.json({ count: rows.length, results: rows, next: null, previous: null });
  });
  app.patch("/api/admin/:resource/:id/", ...guard, async (req, res) => {
    const resource = req.params.resource;
    if (
      !resources.includes(resource) ||
      ["bookings", "quotes", "promotions"].includes(resource)
    )
      reject("This resource is read-only.");
    const data = values(resource, req.body);
    if (!Object.keys(data).length) reject("Supply an editable field.");
    const result = await db.transaction(async (tx) => {
      await find(tx, resource, req.params.id);
      const row = await tx.update(resource, integer(req.params.id, "ID"), data);
      if (resource === "users" && data.is_active === 0) {
        await tx.update("users", row.id, {
          session_version: row.session_version + 1,
        });
        await tx.query(
          "UPDATE refresh_sessions SET revoked=1 WHERE user_id=?",
          [row.id],
        );
      }
      return resource === "users" ? publicUser(row) : row;
    });
    res.json(result);
  });
  app.post("/api/admin/:resource/", ...guard, async (req, res) => {
    const resource = req.params.resource;
    if (!["categories", "areas", "packages"].includes(resource))
      reject("This resource cannot be created here.");
    const data = values(resource, req.body);
    if (
      !data.name ||
      (resource === "areas" &&
        (data.latitude == null || data.longitude == null)) ||
      (resource === "packages" && (data.days == null || data.price == null))
    )
      reject("Complete the required fields.");
    if (resource === "categories") data.icon ??= "handyman";
    if (resource === "areas") data.city ??= "Dhaka";
    res
      .status(201)
      .json(await db.transaction((tx) => tx.insert(resource, data)));
  });
  app.post("/api/admin/promotions/:id/confirm/", ...guard, async (req, res) => {
    if (req.body.confirm !== true)
      reject("Confirm that payment was received and independently verified.");
    res.json(
      await db.transaction(async (tx) =>
        presentedPromotion(
          tx,
          await activatePromotion(tx, integer(req.params.id, "promotion ID")),
        ),
      ),
    );
  });
  app.post("/api/admin/promotions/:id/cancel/", ...guard, async (req, res) => {
    res.json(
      await db.transaction(async (tx) => {
        await find(tx, "promotions", req.params.id);
        return presentedPromotion(
          tx,
          await tx.update(
            "promotions",
            integer(req.params.id, "promotion ID"),
            { status: "cancelled" },
          ),
        );
      }),
    );
  });
}
