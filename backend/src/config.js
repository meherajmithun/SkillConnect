import { fileURLToPath } from "node:url";
import path from "node:path";

export const backendRoot = fileURLToPath(new URL("..", import.meta.url));
const flag = (value, fallback = false) =>
  value == null ? fallback : value === "true";
const list = (value) =>
  (value || "")
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);

export function configuration(env = process.env) {
  const production = env.NODE_ENV === "production";
  const databaseUrl = env.DATABASE_URL || "";
  const secret = env.JWT_SECRET || "";
  if (production && (!secret || secret.length < 32))
    throw new Error("Set JWT_SECRET to at least 32 random characters.");
  if (production && !databaseUrl && !env.POSTGRES_DB)
    throw new Error("Configure PostgreSQL for production.");
  const hosts = list(env.ALLOWED_HOSTS);
  if (production && (!hosts.length || hosts.includes("*")))
    throw new Error("Set exact ALLOWED_HOSTS in production.");
  const dataDir = path.resolve(env.DATA_DIR || path.join(backendRoot, "data"));
  return {
    production,
    port: Number(env.PORT || 8000),
    host: env.HOST || "0.0.0.0",
    secret: secret || "local-development-only-change-before-deployment",
    databaseUrl,
    postgres: env.POSTGRES_DB
      ? {
          database: env.POSTGRES_DB,
          user: env.POSTGRES_USER || "skillconnect",
          password: env.POSTGRES_PASSWORD,
          host: env.POSTGRES_HOST || "localhost",
          port: Number(env.POSTGRES_PORT || 5432),
        }
      : null,
    databaseSsl: flag(env.DATABASE_SSL),
    dataDir,
    sqlitePath: env.SQLITE_PATH || path.join(dataDir, "skillconnect.sqlite3"),
    mediaDir: path.resolve(env.MEDIA_DIR || path.join(backendRoot, "media")),
    mediaBaseUrl: env.MEDIA_BASE_URL || "",
    hosts,
    corsOrigins: list(
      env.CORS_ALLOWED_ORIGINS || "http://localhost:8080,http://localhost:3000",
    ),
    trustProxy: env.TRUST_PROXY ? Number(env.TRUST_PROXY) : false,
    publicOrigin: env.PUBLIC_ORIGIN || "",
    demoPayments: !production && flag(env.DEMO_PAYMENTS),
    emailMode: env.EMAIL_MODE || (production ? "smtp" : "console"),
    email: {
      host: env.EMAIL_HOST,
      port: Number(env.EMAIL_PORT || 587),
      secure: flag(env.EMAIL_SECURE),
      requireTLS: flag(env.EMAIL_USE_TLS, true),
      auth: env.EMAIL_HOST_USER
        ? { user: env.EMAIL_HOST_USER, pass: env.EMAIL_HOST_PASSWORD }
        : undefined,
      connectionTimeout: 15000,
      greetingTimeout: 15000,
      socketTimeout: 15000,
    },
    emailFrom:
      env.DEFAULT_FROM_EMAIL || "SkillConnect <noreply@skillconnect.local>",
    payment: {
      storeId: env.SSLCOMMERZ_STORE_ID || "",
      password: env.SSLCOMMERZ_STORE_PASSWORD || "",
      sandbox: flag(env.SSLCOMMERZ_SANDBOX, true),
      callback: env.PAYMENT_CALLBACK_BASE_URL || "",
    },
    firebaseCredentials: env.FIREBASE_CREDENTIALS || "",
    rateLimit: true,
  };
}
