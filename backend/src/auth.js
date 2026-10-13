import {
  randomBytes,
  randomInt,
  randomUUID,
  scrypt,
  pbkdf2,
  timingSafeEqual,
} from "node:crypto";
import { promisify } from "node:util";
import jwt from "jsonwebtoken";
import nodemailer from "nodemailer";
import {
  HttpError,
  reject,
  text,
  email,
  timestamp,
  publicUser,
  find,
} from "./validation.js";

const derive = promisify(scrypt),
  derivePbkdf = promisify(pbkdf2);
export function validatePassword(value, user = {}) {
  if (
    typeof value !== "string" ||
    value.length < 8 ||
    value.length > 128 ||
    /^\d+$/.test(value) ||
    ["password", "password123", "qwerty123"].includes(value.toLowerCase())
  )
    reject("Use a strong password of 8–128 characters.");
  if (
    [user.username, user.email?.split("@")[0]].some(
      (part) =>
        part?.length >= 4 && value.toLowerCase().includes(part.toLowerCase()),
    )
  )
    reject("Choose a password that does not contain your account details.");
  return value;
}
export async function hashPassword(value) {
  const salt = randomBytes(16).toString("hex");
  const hash = await derive(value, salt, 64);
  return `scrypt$${salt}$${hash.toString("hex")}`;
}
export async function checkPassword(value, encoded) {
  if (typeof value !== "string" || typeof encoded !== "string") return false;
  const parts = encoded.split("$");
  let hash, expected;
  if (parts[0] === "scrypt" && parts.length === 3) {
    hash = await derive(value, parts[1], 64);
    expected = Buffer.from(parts[2], "hex");
  } else if (
    parts[0] === "pbkdf2_sha256" &&
    parts.length === 4 &&
    Number(parts[1]) > 0 &&
    Number(parts[1]) <= 2000000
  ) {
    // Preserve password hashes imported from the previous local database.
    hash = await derivePbkdf(value, parts[2], Number(parts[1]), 32, "sha256");
    expected = Buffer.from(parts[3], "base64");
  } else return false;
  return hash.length === expected.length && timingSafeEqual(hash, expected);
}
export function authentication(db, config) {
  const verify = (token, type) => {
    try {
      const payload = jwt.verify(token, config.secret, {
        algorithms: ["HS256"],
        issuer: "skillconnect-js",
      });
      if (payload.token_type !== type) throw new Error();
      return payload;
    } catch {
      throw new HttpError(401, "Please sign in again.");
    }
  };
  const tokenPair = async (tx, user) => {
    const fields = { user_id: user.id, session_version: user.session_version };
    const jti = randomUUID();
    const access = jwt.sign(
      { ...fields, token_type: "access" },
      config.secret,
      {
        algorithm: "HS256",
        expiresIn: "30m",
        issuer: "skillconnect-js",
        jwtid: randomUUID(),
      },
    );
    const refresh = jwt.sign(
      { ...fields, token_type: "refresh" },
      config.secret,
      {
        algorithm: "HS256",
        expiresIn: "7d",
        issuer: "skillconnect-js",
        jwtid: jti,
      },
    );
    await tx.insert("refresh_sessions", {
      jti,
      user_id: user.id,
      expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
      revoked: 0,
    });
    return { access, refresh };
  };
  const activeUser = async (tx, payload) => {
    const user = await tx.one(
      "SELECT * FROM users WHERE id=? AND is_active=1",
      [payload.user_id],
    );
    if (!user || user.session_version !== payload.session_version)
      reject("Please sign in again.", 401);
    return user;
  };
  const authenticate = async (req, res, next) => {
    const value = req.get("authorization");
    if (!value?.startsWith("Bearer ")) reject("Authentication required.", 401);
    req.user = await db.read((tx) =>
      activeUser(tx, verify(value.slice(7), "access")),
    );
    next();
  };
  const staff = (req, res, next) => {
    if (!req.user?.is_staff) reject("Administrator access required.", 403);
    next();
  };
  const sendEmail =
    config.sendEmail ||
    (async ({ to, code, purpose }) => {
      if (config.emailMode === "console" && !config.production) {
        console.log(
          `SkillConnect ${purpose} email to ${to}: ${code} (expires in 15 minutes)`,
        );
        return;
      }
      if (!config.email.host) throw new Error("SMTP is not configured.");
      await nodemailer.createTransport(config.email).sendMail({
        from: config.emailFrom,
        to,
        subject: "SkillConnect email code",
        text: `Your code to ${purpose === "reset" ? "reset your password" : "verify your email"} is ${code}. It expires in 15 minutes. Ignore this email if you did not request it.`,
      });
    });
  const issueCode = async (user, purpose) => {
    const code = String(randomInt(100000000)).padStart(8, "0");
    await db.transaction(async (tx) => {
      const current = await find(tx, "users", user.id);
      await tx.query(
        "UPDATE challenges SET used=1 WHERE user_id=? AND purpose=?",
        [user.id, purpose],
      );
      await tx.insert("challenges", {
        user_id: current.id,
        email: current.email,
        purpose,
        code_hash: await hashPassword(code),
        expires_at: new Date(Date.now() + 900000).toISOString(),
        attempts: 0,
        used: 0,
        created_at: timestamp(),
      });
    });
    await sendEmail({ to: user.email, code, purpose });
  };
  const consumeCode = async (userId, purpose, code, password) =>
    db.transaction(async (tx) => {
      const user = await find(tx, "users", userId);
      const challenge = await tx.one(
        "SELECT * FROM challenges WHERE user_id=? AND purpose=? AND email=? AND used=0 ORDER BY id DESC LIMIT 1",
        [user.id, purpose, user.email],
      );
      if (
        !challenge ||
        challenge.expires_at <= timestamp() ||
        challenge.attempts >= 5
      )
        return false;
      const valid = await checkPassword(code, challenge.code_hash);
      await tx.update("challenges", challenge.id, {
        attempts: challenge.attempts + 1,
        used: Number(valid || challenge.attempts + 1 >= 5),
      });
      if (!valid) return false;
      if (purpose === "reset") {
        await tx.update("users", user.id, {
          password: await hashPassword(password),
          session_version: user.session_version + 1,
        });
        await tx.query(
          "UPDATE refresh_sessions SET revoked=1 WHERE user_id=?",
          [user.id],
        );
        await tx.query(
          "UPDATE challenges SET used=1 WHERE user_id=? AND purpose='reset'",
          [user.id],
        );
      } else await tx.update("users", user.id, { email_verified: 1 });
      return true;
    });

  function routes(app, throttle) {
    app.post("/api/auth/register/", throttle("auth", 20), async (req, res) => {
      const b = req.body;
      const username = text(b.username, "username", 150);
      if (!/^[\w.@+-]+$/.test(username))
        reject("Use letters, numbers and . @ + - _ for your username.");
      if (!["customer", "professional"].includes(b.role || "customer"))
        reject("Choose a customer or professional role.");
      const values = {
        username,
        email: email(b.email),
        role: b.role || "customer",
        first_name: text(b.first_name ?? "", "first name", 150, true),
        last_name: text(b.last_name ?? "", "last name", 150, true),
        phone: text(b.phone ?? "", "phone", 20, true),
      };
      validatePassword(b.password, values);
      const password = await hashPassword(b.password);
      const user = await db.transaction(async (tx) => {
        if (
          await tx.one(
            "SELECT id FROM users WHERE username=? OR LOWER(email)=?",
            [username, values.email],
          )
        )
          reject("Username or email is already registered.");
        const result = await tx.insert("users", {
          ...values,
          password,
          created_at: timestamp(),
        });
        if (result.role === "professional")
          await tx.insert("professionals", {
            user_id: result.id,
            business_name:
              [result.first_name, result.last_name].join(" ").trim() ||
              username,
            created_at: timestamp(),
          });
        return publicUser(result);
      });
      res.status(201).json(user);
    });
    app.post("/api/auth/login/", throttle("auth", 20), async (req, res) => {
      const username = text(
          req.body.username ?? req.body.email,
          "email or username",
          254,
        ),
        password = req.body.password;
      if (typeof password !== "string" || !password || password.length > 128)
        reject("Enter your password.");
      const result = await db.transaction(async (tx) => {
        const user = await tx.one(
          "SELECT * FROM users WHERE (username=? OR LOWER(email)=LOWER(?)) AND is_active=1 ORDER BY CASE WHEN LOWER(email)=LOWER(?) THEN 0 ELSE 1 END LIMIT 1",
          [username, username, username],
        );
        if (!(await checkPassword(password, user?.password)))
          reject("Invalid email, username or password.", 401);
        return tokenPair(tx, user);
      });
      res.json(result);
    });
    app.post("/api/auth/refresh/", throttle("auth", 20), async (req, res) => {
      const payload = verify(
        text(req.body.refresh, "refresh token", 4096),
        "refresh",
      );
      const result = await db.transaction(async (tx) => {
        const user = await activeUser(tx, payload);
        const session = await tx.one(
          "SELECT * FROM refresh_sessions WHERE jti=? AND user_id=? AND revoked=0",
          [payload.jti, user.id],
        );
        if (!session || session.expires_at <= timestamp())
          reject("Please sign in again.", 401);
        await tx.query("UPDATE refresh_sessions SET revoked=1 WHERE jti=?", [
          payload.jti,
        ]);
        return tokenPair(tx, user);
      });
      res.json(result);
    });
    app.post("/api/auth/logout/", async (req, res) => {
      const payload = verify(
        text(req.body.refresh, "refresh token", 4096),
        "refresh",
      );
      await db.transaction((tx) =>
        tx.query(
          "UPDATE refresh_sessions SET revoked=1 WHERE jti=? AND user_id=?",
          [payload.jti, payload.user_id],
        ),
      );
      res.json({ detail: "Signed out." });
    });
    app.get("/api/me/", authenticate, (req, res) =>
      res.json(publicUser(req.user)),
    );
    app.patch("/api/me/", authenticate, async (req, res) => {
      const values = {};
      for (const key of ["first_name", "last_name", "phone"])
        if (key in req.body)
          values[key] = text(
            req.body[key],
            key,
            key === "phone" ? 20 : 150,
            true,
          );
      if ("email" in req.body) values.email = email(req.body.email);
      const user = await db.transaction(async (tx) => {
        const current = await find(tx, "users", req.user.id);
        if (values.email && values.email !== current.email) {
          if (
            await tx.one(
              "SELECT id FROM users WHERE LOWER(email)=? AND id<>?",
              [values.email, current.id],
            )
          )
            reject("Email already registered.");
          values.email_verified = 0;
          await tx.query("UPDATE challenges SET used=1 WHERE user_id=?", [
            current.id,
          ]);
        }
        return tx.update("users", current.id, values);
      });
      res.json(publicUser(user));
    });
    app.post(
      "/api/auth/password-reset/",
      throttle("recovery", 20),
      async (req, res) => {
        const address = email(req.body.email);
        const user = await db.read((tx) =>
          tx.one("SELECT * FROM users WHERE LOWER(email)=? AND is_active=1", [
            address,
          ]),
        );
        if (user) {
          try {
            await issueCode(user, "reset");
          } catch {
            console.error("Recovery email delivery failed.");
          }
        }
        res.json({
          detail:
            "If an active account matches, a code has been sent. Check your email.",
        });
      },
    );
    app.post(
      "/api/auth/password-reset/confirm/",
      throttle("recovery", 20),
      async (req, res) => {
        const address = email(req.body.email),
          code = text(req.body.code, "eight-digit code", 8);
        if (!/^\d{8}$/.test(code)) reject("Enter the eight-digit code.");
        const user = await db.read((tx) =>
          tx.one("SELECT * FROM users WHERE LOWER(email)=? AND is_active=1", [
            address,
          ]),
        );
        validatePassword(req.body.new_password, user || {});
        if (
          !user ||
          !(await consumeCode(user.id, "reset", code, req.body.new_password))
        )
          reject("Invalid or expired code. Request a new code.");
        res.json({
          detail: "Password updated. Sign in with your new password.",
        });
      },
    );
    app.post(
      "/api/auth/email-verification/",
      authenticate,
      throttle("recovery", 20),
      async (req, res) => {
        if (req.user.email_verified)
          return res.json({ detail: "Your email is already verified." });
        try {
          await issueCode(req.user, "verify");
        } catch {
          reject("Email delivery is unavailable. Try again later.", 503);
        }
        res.json({ detail: "Verification code sent. Check your email." });
      },
    );
    app.post(
      "/api/auth/email-verification/confirm/",
      authenticate,
      throttle("recovery", 20),
      async (req, res) => {
        const code = text(req.body.code, "eight-digit code", 8);
        if (
          !/^\d{8}$/.test(code) ||
          !(await consumeCode(req.user.id, "verify", code))
        )
          reject("Invalid or expired code. Request a new code.");
        res.json({ detail: "Email verified." });
      },
    );
  }
  return { authenticate, staff, routes };
}
