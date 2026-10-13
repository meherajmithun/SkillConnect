import {
  reject,
  integer,
  text,
  bool,
  amount,
  date,
  find,
  timestamp,
  paginate,
} from "./validation.js";

export const notification = (db, userId, message) =>
  db.insert("notifications", {
    user_id: userId,
    message: message.slice(0, 300),
    created_at: timestamp(),
  });
export async function ownProfile(db, user) {
  if (user.role !== "professional")
    reject("A professional account is required.", 403);
  const pro = await db.one("SELECT * FROM professionals WHERE user_id=?", [
    user.id,
  ]);
  if (!pro) reject("Business profile not found.", 404);
  return pro;
}
export async function profile(db, pro, req, options = {}) {
  const user = await find(db, "users", pro.user_id);
  const categories = await db.all(
    "SELECT c.id,c.name,c.icon FROM categories c JOIN professional_categories pc ON pc.category_id=c.id WHERE pc.professional_id=? AND c.active=1 ORDER BY c.name",
    [pro.id],
  );
  const areas = await db.all(
    "SELECT a.* FROM areas a JOIN professional_areas pa ON pa.area_id=a.id WHERE pa.professional_id=? ORDER BY a.name",
    [pro.id],
  );
  const reviews = await db.one(
    "SELECT AVG(r.rating) AS rating,COUNT(r.id) AS review_count FROM reviews r JOIN bookings b ON b.id=r.booking_id WHERE b.professional_id=? AND r.visible=1",
    [pro.id],
  );
  const portfolio = await db.all(
    "SELECT id,title,description,image FROM portfolio WHERE professional_id=? ORDER BY id",
    [pro.id],
  );
  const mediaOrigin =
    options.mediaBaseUrl || `${req.protocol}://${req.get("host")}/media/`;
  for (const work of portfolio)
    work.image = work.image
      ? new URL(
          work.image,
          mediaOrigin.endsWith("/") ? mediaOrigin : `${mediaOrigin}/`,
        ).href
      : null;
  let distance = null;
  if (options.lat != null && pro.latitude != null) {
    const radians = (v) => (v * Math.PI) / 180;
    const a =
      Math.sin(radians(pro.latitude - options.lat) / 2) ** 2 +
      Math.cos(radians(options.lat)) *
        Math.cos(radians(pro.latitude)) *
        Math.sin(radians(pro.longitude - options.lng) / 2) ** 2;
    distance =
      6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)));
  }
  return {
    id: pro.id,
    name: `${user.first_name} ${user.last_name}`.trim(),
    phone: user.phone,
    business_name: pro.business_name,
    bio: pro.bio,
    skills: pro.skills,
    experience_years: pro.experience_years,
    categories,
    areas,
    available: Boolean(pro.available),
    schedule_enabled: Boolean(pro.schedule_enabled),
    verified: Boolean(pro.verified),
    starting_price: pro.starting_price,
    latitude: pro.latitude,
    longitude: pro.longitude,
    portfolio,
    rating: Number(reviews.rating || 0),
    review_count: Number(reviews.review_count),
    distance_km: distance,
    promoted: Boolean(options.promotedIds?.has(pro.id)),
  };
}
export async function serviceRequest(db, body, user) {
  if (user.role !== "customer")
    reject("Only customers can request services.", 403);
  const pro = await find(db, "professionals", body.professional);
  const owner = await find(db, "users", pro.user_id);
  if (!pro.available || !owner.is_active)
    reject("This professional is currently unavailable.");
  const category = integer(body.category, "service"),
    area = integer(body.area, "area");
  if (
    !(await db.one(
      "SELECT pc.category_id FROM professional_categories pc JOIN categories c ON c.id=pc.category_id WHERE pc.professional_id=? AND pc.category_id=? AND c.active=1",
      [pro.id, category],
    ))
  )
    reject("Choose a service offered by this professional.");
  if (
    !(await db.one(
      "SELECT area_id FROM professional_areas WHERE professional_id=? AND area_id=?",
      [pro.id, area],
    ))
  )
    reject("Choose an area served by this professional.");
  return {
    pro,
    category_id: category,
    area_id: area,
    details: text(body.details, "work details"),
  };
}
export async function bookingConflicts(db, proId, start, end, exclude = 0) {
  const rows = await db.all(
    "SELECT * FROM bookings WHERE professional_id=? AND status IN ('pending','accepted') AND id<>? AND scheduled_at<?",
    [proId, exclude, end],
  );
  return rows.some(
    (b) =>
      new Date(
        Date.parse(b.scheduled_at) + b.duration_minutes * 60000,
      ).toISOString() > start,
  );
}
export async function createBooking(db, body, user, quote = null) {
  const data = await serviceRequest(db, body, user);
  const scheduled = date(body.scheduled_at, "appointment"),
    duration = integer(body.duration_minutes ?? 60, "duration", 30, 480);
  if (scheduled <= timestamp()) reject("Choose a future appointment.");
  const end = new Date(Date.parse(scheduled) + duration * 60000).toISOString();
  const slotId = body.slot == null ? null : integer(body.slot, "slot");
  if (data.pro.schedule_enabled && !slotId)
    reject("Choose a published appointment.");
  if (slotId) {
    const slot = await find(db, "slots", slotId);
    if (
      slot.professional_id !== data.pro.id ||
      slot.starts_at !== scheduled ||
      slot.ends_at !== end
    )
      reject("The appointment must match this professional’s published slot.");
  }
  if (await bookingConflicts(db, data.pro.id, scheduled, end))
    reject("This time is reserved. Choose another appointment.");
  const row = await db.insert("bookings", {
    customer_id: user.id,
    professional_id: data.pro.id,
    category_id: data.category_id,
    area_id: data.area_id,
    scheduled_at: scheduled,
    duration_minutes: duration,
    slot_id: slotId,
    quote_id: quote?.id || null,
    agreed_price: quote?.amount || null,
    agreed_terms: quote?.response || "",
    address: text(body.address, "service address", 300),
    details: data.details,
    status: "pending",
    created_at: timestamp(),
    updated_at: timestamp(),
  });
  await notification(
    db,
    data.pro.user_id,
    `New booking #${row.id}: ${(await find(db, "categories", row.category_id)).name}`,
  );
  return row;
}
export async function participant(db, kind, id, user) {
  const row = await find(db, kind, id),
    pro = await find(db, "professionals", row.professional_id);
  if (row.customer_id !== user.id && pro.user_id !== user.id)
    reject("Not found.", 404);
  return { row, pro, isPro: pro.user_id === user.id };
}
export async function presentedRequest(db, kind, row) {
  const pro = await find(db, "professionals", row.professional_id),
    customer = await find(db, "users", row.customer_id);
  const result = {
    id: row.id,
    professional: pro.id,
    professional_name: pro.business_name,
    customer_name:
      `${customer.first_name} ${customer.last_name}`.trim() ||
      customer.username,
    customer_phone: customer.phone,
    professional_phone: (await find(db, "users", pro.user_id)).phone,
    category: row.category_id,
    category_name: (await find(db, "categories", row.category_id)).name,
    area: row.area_id,
    area_name: (await find(db, "areas", row.area_id)).name,
    details: row.details,
    created_at: row.created_at,
  };
  if (kind === "quotes")
    return {
      ...result,
      amount: row.amount,
      response: row.response,
      revision: row.revision,
      booking_id:
        (await db.one("SELECT id FROM bookings WHERE quote_id=?", [row.id]))
          ?.id || null,
    };
  const review = await db.one("SELECT * FROM reviews WHERE booking_id=?", [
    row.id,
  ]);
  return {
    ...result,
    scheduled_at: row.scheduled_at,
    duration_minutes: row.duration_minutes,
    slot: row.slot_id,
    quote: row.quote_id,
    agreed_price: row.agreed_price,
    agreed_terms: row.agreed_terms,
    address: row.address,
    status: row.status,
    review: review
      ? {
          id: review.id,
          booking: row.id,
          rating: review.rating,
          comment: review.comment,
          customer_name: result.customer_name,
          created_at: review.created_at,
        }
      : null,
  };
}
export async function activatePromotion(db, id) {
  const row = await find(db, "promotions", id);
  if (row.status !== "pending") return row;
  const start = timestamp();
  const result = await db.update("promotions", id, {
    status: "paid",
    starts_at: start,
    expires_at: new Date(
      Date.parse(start) + row.duration_days * 86400000,
    ).toISOString(),
  });
  const pro = await find(db, "professionals", row.professional_id);
  await notification(
    db,
    pro.user_id,
    `Promotion #${id} is active in ${(await find(db, "areas", row.area_id)).name}.`,
  );
  return result;
}
export async function presentedPromotion(db, row) {
  return {
    id: row.id,
    package: row.package_id,
    package_name: (await find(db, "packages", row.package_id)).name,
    category: row.category_id,
    category_name: (await find(db, "categories", row.category_id)).name,
    area: row.area_id,
    area_name: (await find(db, "areas", row.area_id)).name,
    price_paid: row.price_paid,
    status: row.status,
    starts_at: row.starts_at,
    expires_at: row.expires_at,
    active: Boolean(
      row.status === "paid" &&
      row.starts_at <= timestamp() &&
      row.expires_at > timestamp(),
    ),
    created_at: row.created_at,
  };
}

export function marketplaceRoutes(app, db, config, auth) {
  const guard = auth.authenticate;
  app.get("/api/categories/", async (req, res) =>
    res.json(
      await db.read((tx) =>
        tx.all(
          "SELECT id,name,icon FROM categories WHERE active=1 ORDER BY name",
        ),
      ),
    ),
  );
  app.get("/api/areas/", async (req, res) =>
    res.json(
      await db.read((tx) => tx.all("SELECT * FROM areas ORDER BY name")),
    ),
  );
  app.get("/api/packages/", async (req, res) =>
    res.json(
      await db.read((tx) =>
        tx.all(
          "SELECT id,name,days,price FROM packages WHERE active=1 ORDER BY days",
        ),
      ),
    ),
  );
  app.get("/api/professionals/", async (req, res) => {
    const q = req.query,
      category = q.category ? integer(q.category, "category") : null,
      area = q.area ? integer(q.area, "area") : null;
    const rating = Number(q.min_rating || 0),
      lat = q.lat == null ? null : Number(q.lat),
      lng = q.lng == null ? null : Number(q.lng),
      maxDistance = q.max_distance == null ? null : Number(q.max_distance);
    if (
      !Number.isFinite(rating) ||
      rating < 0 ||
      rating > 5 ||
      (lat == null) !== (lng == null) ||
      (lat != null &&
        (!Number.isFinite(lat) ||
          lat < -90 ||
          lat > 90 ||
          !Number.isFinite(lng) ||
          lng < -180 ||
          lng > 180)) ||
      (maxDistance != null &&
        (!Number.isFinite(maxDistance) || maxDistance <= 0 || lat == null))
    )
      reject(
        "Use valid filters and coordinates; distance requires latitude and longitude.",
      );
    const rows = await db.read(async (tx) => {
      const ads =
        category && area
          ? await tx.all(
              "SELECT professional_id FROM promotions WHERE category_id=? AND area_id=? AND status='paid' AND starts_at<=? AND expires_at>?",
              [category, area, timestamp(), timestamp()],
            )
          : [];
      const all = await tx.all(
        "SELECT p.* FROM professionals p JOIN users u ON u.id=p.user_id WHERE u.is_active=1",
      );
      const profiles = await Promise.all(
        all.map((p) =>
          profile(tx, p, req, {
            ...config,
            lat,
            lng,
            promotedIds: new Set(ads.map((a) => a.professional_id)),
          }),
        ),
      );
      return profiles.filter(
        (p) =>
          p.categories.length > 0 &&
          p.areas.length > 0 &&
          (!category || p.categories.some((c) => c.id === category)) &&
          (!area || p.areas.some((a) => a.id === area)) &&
          p.rating >= rating &&
          (q.available !== "true" || p.available) &&
          (!q.q ||
            `${p.business_name} ${p.skills} ${p.bio}`
              .toLowerCase()
              .includes(String(q.q).toLowerCase())) &&
          (maxDistance == null ||
            (p.distance_km != null && p.distance_km <= maxDistance)),
      );
    });
    const score = (p) =>
      p.rating +
      (p.bio ? 0.1 : 0) +
      (p.portfolio.length ? 0.1 : 0) +
      (p.verified ? 0.1 : 0) +
      (p.promoted ? 0.3 : 0) -
      (p.distance_km || 0) * 0.02;
    rows.sort(
      (a, b) =>
        (q.sort === "rating"
          ? b.rating - a.rating
          : q.sort === "distance"
            ? (a.distance_km ?? Infinity) - (b.distance_km ?? Infinity)
            : score(b) - score(a)) || a.id - b.id,
    );
    res.json(paginate(rows, req));
  });
  app.get("/api/professionals/:id/", async (req, res) =>
    res.json(
      await db.read(async (tx) => {
        const pro = await find(tx, "professionals", req.params.id);
        if (!(await find(tx, "users", pro.user_id)).is_active)
          reject("Not found.", 404);
        return profile(tx, pro, req, config);
      }),
    ),
  );
  app.get("/api/professionals/:id/reviews/", async (req, res) =>
    res.json(
      await db.read(async (tx) => {
        const pro = await find(tx, "professionals", req.params.id);
        if (!(await find(tx, "users", pro.user_id)).is_active)
          reject("Not found.", 404);
        const rows = await tx.all(
          "SELECT r.*,u.first_name,u.last_name FROM reviews r JOIN bookings b ON b.id=r.booking_id JOIN users u ON u.id=b.customer_id WHERE b.professional_id=? AND r.visible=1 ORDER BY r.id DESC",
          [pro.id],
        );
        return paginate(
          rows.map((r) => ({
            id: r.id,
            booking: r.booking_id,
            rating: r.rating,
            comment: r.comment,
            customer_name: `${r.first_name} ${r.last_name}`.trim(),
            created_at: r.created_at,
          })),
          req,
        );
      }),
    ),
  );
  app.get("/api/professionals/:id/availability/", async (req, res) =>
    res.json(
      await db.read(async (tx) => {
        const pro = await find(tx, "professionals", req.params.id);
        if (!(await find(tx, "users", pro.user_id)).is_active)
          reject("Not found.", 404);
        const all = pro.available
          ? await tx.all(
              "SELECT * FROM slots WHERE professional_id=? AND starts_at>? AND starts_at<=? ORDER BY starts_at",
              [
                pro.id,
                timestamp(),
                new Date(Date.now() + 90 * 86400000).toISOString(),
              ],
            )
          : [];
        const slots = [];
        for (const s of all)
          if (!(await bookingConflicts(tx, pro.id, s.starts_at, s.ends_at)))
            slots.push({
              id: s.id,
              starts_at: s.starts_at,
              ends_at: s.ends_at,
            });
        return {
          schedule_enabled: Boolean(pro.schedule_enabled),
          slots: slots.slice(0, 500),
        };
      }),
    ),
  );
  app.get("/api/profile/", guard, async (req, res) =>
    res.json(
      await db.read(async (tx) =>
        profile(tx, await ownProfile(tx, req.user), req, config),
      ),
    ),
  );
  app.patch("/api/profile/", guard, async (req, res) =>
    res.json(
      await db.transaction(async (tx) => {
        const pro = await ownProfile(tx, req.user),
          b = req.body,
          values = {};
        for (const [key, max] of [
          ["business_name", 120],
          ["bio", 2000],
          ["skills", 500],
        ])
          if (key in b)
            values[key] = text(b[key], key, max, key !== "business_name");
        if ("experience_years" in b)
          values.experience_years = integer(
            b.experience_years,
            "experience",
            0,
            80,
          );
        if ("starting_price" in b)
          values.starting_price = amount(b.starting_price);
        for (const key of ["available", "schedule_enabled"])
          if (key in b) values[key] = bool(b[key], key);
        const lat = "latitude" in b ? b.latitude : pro.latitude,
          lng = "longitude" in b ? b.longitude : pro.longitude;
        if (
          (lat == null) !== (lng == null) ||
          (lat != null &&
            (typeof lat !== "number" ||
              typeof lng !== "number" ||
              !Number.isFinite(lat) ||
              !Number.isFinite(lng) ||
              lat < -90 ||
              lat > 90 ||
              lng < -180 ||
              lng > 180))
        )
          reject("Supply both valid coordinates or leave both empty.");
        if ("latitude" in b || "longitude" in b)
          Object.assign(values, { latitude: lat, longitude: lng });
        for (const [key, table, column, source] of [
          [
            "category_ids",
            "professional_categories",
            "category_id",
            "categories",
          ],
          ["area_ids", "professional_areas", "area_id", "areas"],
        ]) {
          if (!(key in b)) continue;
          if (!Array.isArray(b[key])) reject(`Use a list for ${key}.`);
          const ids = [...new Set(b[key].map((id) => integer(id, key)))];
          for (const id of ids) {
            const target = await find(tx, source, id);
            if (source === "categories" && !target.active)
              reject("Choose an active service.");
          }
          await tx.query(`DELETE FROM ${table} WHERE professional_id=?`, [
            pro.id,
          ]);
          for (const id of ids)
            await tx.insert(table, { professional_id: pro.id, [column]: id });
        }
        return profile(
          tx,
          await tx.update("professionals", pro.id, values),
          req,
          config,
        );
      }),
    ),
  );
  app.get("/api/slots/", guard, async (req, res) =>
    res.json(
      await db.read(async (tx) => {
        const pro = await ownProfile(tx, req.user);
        return paginate(
          await tx.all(
            "SELECT id,starts_at,ends_at FROM slots WHERE professional_id=? AND ends_at>? ORDER BY starts_at",
            [pro.id, timestamp()],
          ),
          req,
        );
      }),
    ),
  );
  app.post("/api/slots/", guard, async (req, res) =>
    res.status(201).json(
      await db.transaction(async (tx) => {
        const pro = await ownProfile(tx, req.user),
          start = date(req.body.starts_at, "start"),
          end = date(req.body.ends_at, "end");
        const minutes = (Date.parse(end) - Date.parse(start)) / 60000;
        if (
          start <= timestamp() ||
          Date.parse(start) > Date.now() + 90 * 86400000 ||
          !Number.isInteger(minutes) ||
          minutes < 30 ||
          minutes > 480
        )
          reject("Publish a future 30–480 minute slot within 90 days.");
        if (
          (await tx.one(
            "SELECT id FROM slots WHERE professional_id=? AND starts_at<? AND ends_at>?",
            [pro.id, end, start],
          )) ||
          (await bookingConflicts(tx, pro.id, start, end))
        )
          reject("This appointment overlaps a reservation.");
        const row = await tx.insert("slots", {
          professional_id: pro.id,
          starts_at: start,
          ends_at: end,
        });
        return { id: row.id, starts_at: start, ends_at: end };
      }),
    ),
  );
  app.delete("/api/slots/:id/", guard, async (req, res) => {
    await db.transaction(async (tx) => {
      const pro = await ownProfile(tx, req.user),
        slot = await find(tx, "slots", req.params.id);
      if (slot.professional_id !== pro.id) reject("Not found.", 404);
      if (await tx.one("SELECT id FROM bookings WHERE slot_id=?", [slot.id]))
        reject("This slot has booking history and cannot be removed.");
      await tx.query("DELETE FROM slots WHERE id=?", [slot.id]);
    });
    res.sendStatus(204);
  });
  for (const kind of ["bookings", "quotes"]) {
    app.get(`/api/${kind}/`, guard, async (req, res) =>
      res.json(
        await db.read(async (tx) => {
          const rows = await tx.all(
            `SELECT r.* FROM ${kind} r JOIN professionals p ON p.id=r.professional_id WHERE r.customer_id=? OR p.user_id=? ORDER BY r.id DESC`,
            [req.user.id, req.user.id],
          );
          return paginate(
            await Promise.all(rows.map((r) => presentedRequest(tx, kind, r))),
            req,
          );
        }),
      ),
    );
    app.post(`/api/${kind}/`, guard, async (req, res) =>
      res.status(201).json(
        await db.transaction(async (tx) => {
          if (kind === "bookings")
            return presentedRequest(
              tx,
              kind,
              await createBooking(tx, req.body, req.user),
            );
          const data = await serviceRequest(tx, req.body, req.user);
          const row = await tx.insert("quotes", {
            customer_id: req.user.id,
            professional_id: data.pro.id,
            category_id: data.category_id,
            area_id: data.area_id,
            details: data.details,
            created_at: timestamp(),
          });
          await notification(
            tx,
            data.pro.user_id,
            `New quotation request #${row.id}.`,
          );
          return presentedRequest(tx, kind, row);
        }),
      ),
    );
    app.get(`/api/${kind}/:id/`, guard, async (req, res) =>
      res.json(
        await db.read(async (tx) =>
          presentedRequest(
            tx,
            kind,
            (await participant(tx, kind, req.params.id, req.user)).row,
          ),
        ),
      ),
    );
    app.get(`/api/${kind}/:id/messages/`, guard, async (req, res) =>
      res.json(
        await db.read(async (tx) => {
          const { row } = await participant(tx, kind, req.params.id, req.user);
          const column = kind === "bookings" ? "booking_id" : "quote_id";
          const rows = await tx.all(
            `SELECT m.*,u.first_name,u.last_name,u.username FROM messages m JOIN users u ON u.id=m.sender_id WHERE m.${column}=? ORDER BY m.id DESC`,
            [row.id],
          );
          return paginate(
            rows.map((m) => ({
              id: m.id,
              sender: m.sender_id,
              sender_name:
                `${m.first_name} ${m.last_name}`.trim() || m.username,
              body: m.body,
              read_at: m.read_at,
              created_at: m.created_at,
            })),
            req,
          );
        }),
      ),
    );
    app.post(`/api/${kind}/:id/messages/`, guard, async (req, res) =>
      res.status(201).json(
        await db.transaction(async (tx) => {
          const { row, pro, isPro } = await participant(
            tx,
            kind,
            req.params.id,
            req.user,
          );
          const message = await tx.insert("messages", {
            [kind === "bookings" ? "booking_id" : "quote_id"]: row.id,
            sender_id: req.user.id,
            body: text(req.body.body, "message"),
            created_at: timestamp(),
          });
          await notification(
            tx,
            isPro ? row.customer_id : pro.user_id,
            `New message on ${kind === "bookings" ? "booking" : "quotation"} #${row.id}. Open Activity to reply.`,
          );
          return {
            id: message.id,
            sender: req.user.id,
            sender_name: `${req.user.first_name} ${req.user.last_name}`.trim(),
            body: message.body,
            read_at: null,
            created_at: message.created_at,
          };
        }),
      ),
    );
    app.post(`/api/${kind}/:id/messages/read/`, guard, async (req, res) => {
      await db.transaction(async (tx) => {
        const { row } = await participant(tx, kind, req.params.id, req.user);
        await tx.query(
          `UPDATE messages SET read_at=? WHERE ${kind === "bookings" ? "booking_id" : "quote_id"}=? AND sender_id<>? AND id<=? AND read_at IS NULL`,
          [
            timestamp(),
            row.id,
            req.user.id,
            integer(req.body.through_id, "message ID"),
          ],
        );
      });
      res.json({ detail: "Messages marked as read." });
    });
  }
  app.post("/api/bookings/:id/status/", guard, async (req, res) =>
    res.json(
      await db.transaction(async (tx) => {
        const { row, isPro } = await participant(
            tx,
            "bookings",
            req.params.id,
            req.user,
          ),
          target = req.body.status;
        const allowed = isPro
          ? { pending: ["accepted", "rejected"], accepted: ["completed"] }
          : { pending: ["cancelled"], accepted: ["cancelled"] };
        if (!allowed[row.status]?.includes(target))
          reject("This booking status change is not allowed.");
        if (target === "accepted" && row.scheduled_at <= timestamp())
          reject("This appointment has passed.");
        const updated = await tx.update("bookings", row.id, {
          status: target,
          updated_at: timestamp(),
        });
        const pro = await find(tx, "professionals", row.professional_id);
        await notification(
          tx,
          isPro ? row.customer_id : pro.user_id,
          `Booking #${row.id} is ${target}.`,
        );
        return presentedRequest(tx, "bookings", updated);
      }),
    ),
  );
  app.post("/api/quotes/:id/reply/", guard, async (req, res) =>
    res.json(
      await db.transaction(async (tx) => {
        const { row, isPro } = await participant(
          tx,
          "quotes",
          req.params.id,
          req.user,
        );
        if (!isPro) reject("Only the requested professional can reply.", 403);
        if (await tx.one("SELECT id FROM bookings WHERE quote_id=?", [row.id]))
          reject("This estimate has already been accepted.");
        const updated = await tx.update("quotes", row.id, {
          amount: amount(req.body.amount, 1),
          response: text(req.body.response, "included work"),
          revision: row.revision + 1,
        });
        await notification(
          tx,
          row.customer_id,
          `Quotation #${row.id}: BDT ${updated.amount}.`,
        );
        return presentedRequest(tx, "quotes", updated);
      }),
    ),
  );
  app.post("/api/quotes/:id/accept/", guard, async (req, res) =>
    res.json(
      await db.transaction(async (tx) => {
        const { row } = await participant(
          tx,
          "quotes",
          req.params.id,
          req.user,
        );
        if (row.customer_id !== req.user.id)
          reject("Only the requesting customer can accept.", 403);
        const existing = await tx.one(
          "SELECT * FROM bookings WHERE quote_id=?",
          [row.id],
        );
        if (existing) return presentedRequest(tx, "bookings", existing);
        if (row.amount == null) reject("Wait for an estimate first.");
        if (
          integer(req.body.quote_revision, "quote revision", 0) !== row.revision
        )
          reject("This estimate changed. Refresh before accepting.");
        const booking = await createBooking(
          tx,
          {
            ...req.body,
            professional: row.professional_id,
            category: row.category_id,
            area: row.area_id,
            details: row.details,
          },
          req.user,
          row,
        );
        return presentedRequest(tx, "bookings", booking);
      }),
    ),
  );
  app.post("/api/reviews/", guard, async (req, res) =>
    res.status(201).json(
      await db.transaction(async (tx) => {
        const booking = await find(tx, "bookings", req.body.booking);
        if (
          booking.customer_id !== req.user.id ||
          booking.status !== "completed"
        )
          reject("Review only your own completed booking.");
        if (
          await tx.one("SELECT id FROM reviews WHERE booking_id=?", [
            booking.id,
          ])
        )
          reject("This booking already has a review.");
        const row = await tx.insert("reviews", {
          booking_id: booking.id,
          rating: integer(req.body.rating, "rating", 1, 5),
          comment: text(req.body.comment, "review", 1000),
          created_at: timestamp(),
        });
        return {
          id: row.id,
          booking: booking.id,
          rating: row.rating,
          comment: row.comment,
          customer_name: `${req.user.first_name} ${req.user.last_name}`.trim(),
          created_at: row.created_at,
        };
      }),
    ),
  );
  app.get("/api/promotions/", guard, async (req, res) =>
    res.json(
      await db.read(async (tx) => {
        const pro = await ownProfile(tx, req.user);
        return paginate(
          await Promise.all(
            (
              await tx.all(
                "SELECT * FROM promotions WHERE professional_id=? ORDER BY id DESC",
                [pro.id],
              )
            ).map((r) => presentedPromotion(tx, r)),
          ),
          req,
        );
      }),
    ),
  );
  app.post("/api/promotions/", guard, async (req, res) =>
    res.status(201).json(
      await db.transaction(async (tx) => {
        const pro = await ownProfile(tx, req.user),
          pack = await find(tx, "packages", req.body.package);
        if (!pack.active) reject("Choose an active package.");
        const category = integer(req.body.category, "service"),
          area = integer(req.body.area, "area");
        if (
          !(await tx.one(
            "SELECT pc.category_id FROM professional_categories pc JOIN categories c ON c.id=pc.category_id WHERE pc.professional_id=? AND pc.category_id=? AND c.active=1",
            [pro.id, category],
          )) ||
          !(await tx.one(
            "SELECT area_id FROM professional_areas WHERE professional_id=? AND area_id=?",
            [pro.id, area],
          ))
        )
          reject("Choose one of your services and areas.");
        let row = await tx.insert("promotions", {
          professional_id: pro.id,
          package_id: pack.id,
          category_id: category,
          area_id: area,
          price_paid: pack.price,
          duration_days: pack.days,
          status: "pending",
          created_at: timestamp(),
        });
        if (config.demoPayments) row = await activatePromotion(tx, row.id);
        return presentedPromotion(tx, row);
      }),
    ),
  );
  app.get("/api/notifications/", guard, async (req, res) =>
    res.json(
      await db.read(async (tx) =>
        paginate(
          (
            await tx.all(
              "SELECT id,message,read,created_at FROM notifications WHERE user_id=? ORDER BY id DESC",
              [req.user.id],
            )
          ).map((n) => ({ ...n, read: Boolean(n.read) })),
          req,
        ),
      ),
    ),
  );
  app.post("/api/notifications/read-all/", guard, async (req, res) => {
    await db.transaction((tx) =>
      tx.query("UPDATE notifications SET read=1 WHERE user_id=?", [
        req.user.id,
      ]),
    );
    res.json({ detail: "Notifications marked as read." });
  });
  app.get("/api/reports/", guard, async (req, res) =>
    res.json(
      await db.read(async (tx) =>
        paginate(
          (
            await tx.all(
              "SELECT * FROM reports WHERE reporter_id=? ORDER BY id DESC",
              [req.user.id],
            )
          ).map((r) => ({
            id: r.id,
            professional: r.professional_id,
            reason: r.reason,
            resolved: Boolean(r.resolved),
            resolution: r.resolution,
            created_at: r.created_at,
          })),
          req,
        ),
      ),
    ),
  );
  app.post("/api/reports/", guard, async (req, res) =>
    res.status(201).json(
      await db.transaction(async (tx) => {
        const pro = await find(tx, "professionals", req.body.professional);
        const row = await tx.insert("reports", {
          reporter_id: req.user.id,
          professional_id: pro.id,
          reason: text(req.body.reason, "report reason"),
          created_at: timestamp(),
        });
        return {
          id: row.id,
          professional: pro.id,
          reason: row.reason,
          resolved: false,
          resolution: "",
          created_at: row.created_at,
        };
      }),
    ),
  );
  app.get("/api/analytics/", guard, async (req, res) =>
    res.json(
      await db.read(async (tx) => {
        const all = req.user.is_staff;
        const bookings = all
          ? await tx.all("SELECT * FROM bookings")
          : await tx.all(
              "SELECT b.* FROM bookings b JOIN professionals p ON p.id=b.professional_id WHERE b.customer_id=? OR p.user_id=?",
              [req.user.id, req.user.id],
            );
        const data = {
          bookings: bookings.length,
          completed: bookings.filter((b) => b.status === "completed").length,
          pending: bookings.filter((b) => b.status === "pending").length,
        };
        if (all) {
          for (const [key, table, where] of [
            ["users", "users", ""],
            ["professionals", "professionals", ""],
            ["pending_verifications", "professionals", " WHERE verified=0"],
            ["open_reports", "reports", " WHERE resolved=0"],
          ])
            data[key] = Number(
              (await tx.one(`SELECT COUNT(*) AS count FROM ${table}${where}`))
                .count,
            );
          data.promotion_revenue = (
            await tx.all(
              "SELECT price_paid FROM promotions WHERE status='paid'",
            )
          ).reduce((sum, p) => sum + Number(p.price_paid), 0);
        } else {
          data.quotes = Number(
            (
              await tx.one(
                "SELECT COUNT(*) AS count FROM quotes q JOIN professionals p ON p.id=q.professional_id WHERE q.customer_id=? OR p.user_id=?",
                [req.user.id, req.user.id],
              )
            ).count,
          );
          if (req.user.role === "professional") {
            const pro = await ownProfile(tx, req.user);
            data.rating = (await profile(tx, pro, req, config)).rating;
            data.active_promotions = Number(
              (
                await tx.one(
                  "SELECT COUNT(*) AS count FROM promotions WHERE professional_id=? AND status='paid' AND starts_at<=? AND expires_at>?",
                  [pro.id, timestamp(), timestamp()],
                )
              ).count,
            );
          }
        }
        return data;
      }),
    ),
  );
  app.post("/api/devices/", guard, async (req, res) => {
    const token = text(req.body.token, "FCM token", 4096);
    if (token.length < 20) reject("Supply a valid FCM token.");
    await db.transaction((tx) =>
      tx.query(
        "INSERT INTO devices (user_id,token,created_at) VALUES (?,?,?) ON CONFLICT(token) DO UPDATE SET user_id=excluded.user_id",
        [req.user.id, token, timestamp()],
      ),
    );
    res.json({ detail: "Device registered." });
  });
  app.delete("/api/devices/", guard, async (req, res) => {
    const token = text(req.body.token, "FCM token", 4096);
    await db.transaction((tx) =>
      tx.query("DELETE FROM devices WHERE user_id=? AND token=?", [
        req.user.id,
        token,
      ]),
    );
    res.sendStatus(204);
  });
}
