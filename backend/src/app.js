import express from "express";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { backendRoot } from "./config.js";
import { authentication } from "./auth.js";
import { marketplaceRoutes } from "./marketplace.js";
import { payments, paymentEnabled } from "./payments.js";
import { uploadRoutes } from "./uploads.js";
import { adminRoutes } from "./admin.js";
import { reject, timestamp } from "./validation.js";

export function createApp(db, config) {
  const app = express();
  app.disable("x-powered-by");
  app.set("trust proxy", config.trustProxy);
  app.use((req, res, next) => {
    if (config.hosts.length && !config.hosts.includes(req.hostname))
      reject("Invalid host.", 400);
    if (config.production && !req.secure && req.path !== "/api/health/") {
      if (!config.publicOrigin) reject("Use HTTPS.", 400);
      return res.redirect(308, `${config.publicOrigin}${req.originalUrl}`);
    }
    res.set({
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "Referrer-Policy": "same-origin",
      "Content-Security-Policy":
        "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; frame-ancestors 'none'",
    });
    if (config.production)
      res.set(
        "Strict-Transport-Security",
        "max-age=31536000; includeSubDomains",
      );
    if (req.path.startsWith("/api/")) res.set("Cache-Control", "no-store");
    const origin = req.get("origin");
    if (origin && config.corsOrigins.includes(origin)) {
      res.set({
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Headers": "Authorization,Content-Type",
        "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
        Vary: "Origin",
      });
    }
    if (req.method === "OPTIONS") return res.sendStatus(204);
    next();
  });
  app.use(express.json({ limit: "100kb" }));
  app.use(express.urlencoded({ extended: false, limit: "100kb" }));
  const throttle = (scope, limit) => async (req, res, next) => {
    if (!config.rateLimit) return next();
    const key = `${scope}:${req.ip}`;
    const count = await db.transaction(async (tx) => {
      const row = await tx.one("SELECT * FROM rate_limits WHERE key=?", [key]);
      const expired = !row || Date.parse(row.window_at) + 3600000 < Date.now();
      if (expired) {
        await tx.query(
          "INSERT INTO rate_limits (key,window_at,count) VALUES (?,?,1) ON CONFLICT(key) DO UPDATE SET window_at=excluded.window_at,count=1",
          [key, timestamp()],
        );
        return 1;
      }
      await tx.query("UPDATE rate_limits SET count=count+1 WHERE key=?", [key]);
      return row.count + 1;
    });
    if (count > limit) {
      res.set("Retry-After", "3600");
      reject("Too many requests. Try again later.", 429);
    }
    next();
  };
  app.use("/api", (req, res, next) =>
    req.path === "/health/" ? next() : throttle("api", 2000)(req, res, next),
  );
  const auth = authentication(db, config);
  auth.routes(app, throttle);
  marketplaceRoutes(app, db, config, auth);
  payments(db, config).routes(app, auth);
  uploadRoutes(app, db, config, auth);
  adminRoutes(app, db, config, auth);
  app.get("/api/health/", async (req, res) => {
    await db.read((tx) => tx.one("SELECT 1 AS ready"));
    res.json({
      status: "ok",
      service: "SkillConnect",
      backend: "nodejs",
      demo_payments: config.demoPayments,
      online_payments: paymentEnabled(config),
      payment_sandbox: config.payment.sandbox,
    });
  });
  mkdirSync(config.mediaDir, { recursive: true });
  app.use(
    "/media",
    express.static(config.mediaDir, {
      dotfiles: "deny",
      index: false,
      maxAge: "1h",
    }),
  );
  app.use(
    "/admin",
    express.static(path.join(backendRoot, "public"), { index: "index.html" }),
  );
  app.use((req, res) => res.status(404).json({ detail: "Not found." }));
  app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    const duplicate =
      error.code === "23505" ||
      String(error.message).includes("UNIQUE constraint failed");
    const related =
      error.code === "23503" ||
      String(error.message).includes("FOREIGN KEY constraint failed");
    const badBody =
      error.type === "entity.parse.failed" || error.type === "entity.too.large";
    const status =
      error.status ||
      (error.code?.startsWith("LIMIT_") || duplicate || related || badBody
        ? 400
        : 500);
    if (status === 500)
      console.error("Request failed:", error.code || error.name);
    res.status(status).json({
      detail:
        status === 500
          ? "The server could not complete this request."
          : duplicate
            ? "This item already exists."
            : related
              ? "This item is missing or has related history."
              : badBody
                ? "Use a valid request body under 100 KB."
                : error.message,
    });
  });
  return app;
}
