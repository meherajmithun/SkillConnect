import { randomBytes } from "node:crypto";
import { reject, find, timestamp, amount } from "./validation.js";
import { activatePromotion } from "./marketplace.js";

export function paymentEnabled(config) {
  try {
    const url = new URL(config.payment.callback);
    return Boolean(
      config.payment.storeId &&
      config.payment.password &&
      !url.username &&
      !url.password &&
      !url.search &&
      !url.hash &&
      url.pathname === "/" &&
      (url.protocol === "https:" ||
        (config.payment.sandbox && url.protocol === "http:")),
    );
  } catch {
    return false;
  }
}
const publicPayment = (row) => ({
  id: row.id,
  transaction_id: row.transaction_id,
  amount: row.amount,
  status: row.status,
  gateway_url: row.gateway_url,
  sandbox: Boolean(row.sandbox),
  created_at: row.created_at,
});

export function payments(db, config) {
  const credentials = () => ({
    store_id: config.payment.storeId,
    store_passwd: config.payment.password,
  });
  const gateway =
    config.gatewayRequest ||
    (async (method, path, sandbox, data) => {
      try {
        const url = new URL(
          path,
          sandbox
            ? "https://sandbox.sslcommerz.com"
            : "https://securepay.sslcommerz.com",
        );
        const options = { method, signal: AbortSignal.timeout(20000) };
        if (method === "POST") options.body = new URLSearchParams(data);
        else url.search = new URLSearchParams(data).toString();
        const response = await fetch(url, options);
        if (!response.ok) throw new Error();
        const result = await response.json();
        if (!result || typeof result !== "object" || Array.isArray(result))
          throw new Error();
        return result;
      } catch {
        reject(
          "The payment provider is unavailable. Refresh payment status before trying again.",
          503,
        );
      }
    });
  async function checkout(promotionId, user) {
    if (!paymentEnabled(config))
      reject(
        "Online payments are not configured. Contact the administrator for payment confirmation.",
      );
    const prepared = await db.transaction(async (tx) => {
      const pro = await tx.one("SELECT id FROM professionals WHERE user_id=?", [
        user.id,
      ]);
      const promotion = await find(tx, "promotions", promotionId);
      if (promotion.professional_id !== pro?.id) reject("Not found.", 404);
      if (promotion.status !== "pending")
        reject("Only pending promotions can be paid.");
      if (!user.phone)
        reject("Add your phone number in Account before checkout.");
      const previous = await tx.one(
        "SELECT * FROM payments WHERE promotion_id=? AND status<>'failed' ORDER BY id DESC LIMIT 1",
        [promotion.id],
      );
      if (previous) {
        if (previous.status === "pending" && previous.gateway_url)
          return { reuse: previous };
        reject(
          "A payment attempt already exists. Refresh its status or contact the administrator.",
        );
      }
      const payment = await tx.insert("payments", {
        promotion_id: promotion.id,
        amount: promotion.price_paid,
        transaction_id: `SC${randomBytes(12).toString("hex")}`,
        sandbox: Number(config.payment.sandbox),
        status: "initiating",
        created_at: timestamp(),
      });
      return { payment, area: await find(tx, "areas", promotion.area_id) };
    });
    if (prepared.reuse) return publicPayment(prepared.reuse);
    const { payment, area } = prepared,
      callback = `${config.payment.callback.replace(/\/$/, "")}/api/payments/`;
    const result = await gateway(
      "POST",
      "/gwprocess/v4/api.php",
      Boolean(payment.sandbox),
      {
        ...credentials(),
        total_amount: payment.amount,
        currency: "BDT",
        tran_id: payment.transaction_id,
        success_url: `${callback}return/`,
        fail_url: `${callback}return/`,
        cancel_url: `${callback}return/`,
        ipn_url: `${callback}ipn/`,
        cus_name:
          `${user.first_name} ${user.last_name}`.trim() || user.username,
        cus_email: user.email,
        cus_phone: user.phone,
        cus_add1: area.name,
        cus_city: area.city,
        cus_postcode: "1200",
        cus_country: "Bangladesh",
        shipping_method: "NO",
        num_of_item: "1",
        product_name: `Promotion ${payment.promotion_id}`,
        product_category: "service",
        product_profile: "non-physical-goods",
      },
    );
    if (result.status !== "SUCCESS") {
      await db.transaction((tx) =>
        tx.update("payments", payment.id, { status: "failed" }),
      );
      reject(
        "The provider could not create checkout. Check the merchant configuration.",
      );
    }
    let url;
    try {
      url = new URL(result.GatewayPageURL);
    } catch {
      /* Keep unresolved if a provider session might exist. */
    }
    if (
      !url ||
      url.protocol !== "https:" ||
      !["sandbox.sslcommerz.com", "securepay.sslcommerz.com"].includes(
        url.hostname,
      ) ||
      url.username ||
      url.password
    )
      reject("Invalid checkout address. Contact the administrator.");
    return db.transaction(async (tx) => {
      const current = await find(tx, "payments", payment.id);
      return publicPayment(
        await tx.update("payments", payment.id, {
          gateway_url: result.GatewayPageURL,
          session_key: String(result.sessionkey || "").slice(0, 255),
          status: current.status === "initiating" ? "pending" : current.status,
        }),
      );
    });
  }
  async function validate(payment, validationId) {
    if (
      Boolean(payment.sandbox) !== config.payment.sandbox ||
      !paymentEnabled(config)
    )
      reject("The payment environment changed. Contact the administrator.");
    const verified = await gateway(
      "GET",
      "/validator/api/validationserverAPI.php",
      Boolean(payment.sandbox),
      { ...credentials(), val_id: validationId, format: "json" },
    );
    let matches = false;
    try {
      matches =
        verified.tran_id === payment.transaction_id &&
        verified.val_id === validationId &&
        verified.currency === "BDT" &&
        amount(verified.amount) === payment.amount &&
        ["VALID", "VALIDATED"].includes(verified.status);
    } catch {
      /* Invalid amount cannot activate. */
    }
    if (!matches)
      reject("Payment verification failed. The promotion remains unpaid.");
    return db.transaction(async (tx) => {
      const current = await find(tx, "payments", payment.id),
        promotion = await find(tx, "promotions", current.promotion_id);
      if (current.status === "paid") return publicPayment(current);
      const needsReview =
        String(verified.risk_level) !== "0" || promotion.status !== "pending";
      if (!needsReview) await activatePromotion(tx, promotion.id);
      return publicPayment(
        await tx.update("payments", current.id, {
          validation_id: validationId,
          status: needsReview ? "review" : "paid",
        }),
      );
    });
  }
  async function refresh(payment) {
    if (payment.status === "paid") return publicPayment(payment);
    if (
      !paymentEnabled(config) ||
      Boolean(payment.sandbox) !== config.payment.sandbox
    )
      reject(
        "Configure the original payment environment to check this transaction.",
      );
    const lookup = payment.session_key
      ? { sessionkey: payment.session_key }
      : { tran_id: payment.transaction_id };
    const result = await gateway(
      "GET",
      "/validator/api/merchantTransIDvalidationAPI.php",
      Boolean(payment.sandbox),
      { ...credentials(), format: "json", ...lookup },
    );
    const candidates = result.element || [result];
    if (!Array.isArray(candidates))
      reject("The provider returned an unexpected status. Try again later.");
    for (const candidate of candidates) {
      if (candidate?.tran_id !== payment.transaction_id) continue;
      if (["VALID", "VALIDATED"].includes(candidate.status) && candidate.val_id)
        return validate(payment, candidate.val_id);
      if (["FAILED", "CANCELLED"].includes(candidate.status))
        await db.transaction((tx) =>
          tx.query(
            "UPDATE payments SET status='failed' WHERE id=? AND status IN ('pending','initiating')",
            [payment.id],
          ),
        );
    }
    return publicPayment(
      await db.read((tx) => find(tx, "payments", payment.id)),
    );
  }
  function routes(app, auth) {
    app.post(
      "/api/promotions/:id/payment/",
      auth.authenticate,
      async (req, res) => res.json(await checkout(req.params.id, req.user)),
    );
    app.get(
      "/api/promotions/:id/payment/",
      auth.authenticate,
      async (req, res) => {
        const payment = await db.read(async (tx) => {
          const pro = await tx.one(
              "SELECT id FROM professionals WHERE user_id=?",
              [req.user.id],
            ),
            promotion = await find(tx, "promotions", req.params.id);
          if (promotion.professional_id !== pro?.id) reject("Not found.", 404);
          const row = await tx.one(
            "SELECT * FROM payments WHERE promotion_id=? ORDER BY id DESC LIMIT 1",
            [promotion.id],
          );
          if (!row) reject("No payment attempt yet.", 404);
          return row;
        });
        res.json(await refresh(payment));
      },
    );
    app.post("/api/payments/ipn/", async (req, res) => {
      if (
        typeof req.body.tran_id !== "string" ||
        typeof req.body.val_id !== "string" ||
        req.body.val_id.length > 255
      )
        reject("Supply a transaction and validation ID.");
      const payment = await db.read((tx) =>
        tx.one("SELECT * FROM payments WHERE transaction_id=?", [
          req.body.tran_id,
        ]),
      );
      if (!payment) reject("Not found.", 404);
      res.json({ status: (await validate(payment, req.body.val_id)).status });
    });
    app.all("/api/payments/return/", (req, res) =>
      res
        .type("html")
        .send(
          '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>SkillConnect payment</title></head><body><h1>Return to SkillConnect</h1><p>Open Promotions and refresh payment status to verify payment.</p></body></html>',
        ),
    );
  }
  return { checkout, validate, refresh, routes };
}
