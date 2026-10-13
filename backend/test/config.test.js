import test from "node:test";
import assert from "node:assert/strict";
import { configuration } from "../src/config.js";

const production = {
  NODE_ENV: "production",
  JWT_SECRET: "a".repeat(64),
  DATABASE_URL: "postgresql://user:password@internal-host/skillconnect",
};

test("Render production uses its assigned exact hostname and HTTPS origin", () => {
  const config = configuration({
    ...production,
    RENDER: "true",
    RENDER_EXTERNAL_HOSTNAME: "skillconnect-api-unique.onrender.com",
    PORT: "10000",
    TRUST_PROXY: "1",
    DEMO_PAYMENTS: "true",
  });
  assert.deepEqual(config.hosts, ["skillconnect-api-unique.onrender.com"]);
  assert.equal(
    config.publicOrigin,
    "https://skillconnect-api-unique.onrender.com",
  );
  assert.equal(config.port, 10000);
  assert.equal(config.host, "0.0.0.0");
  assert.equal(config.trustProxy, 1);
  assert.equal(config.demoPayments, false);
});

test("explicit host and origin configuration takes precedence on Render", () => {
  const config = configuration({
    ...production,
    RENDER: "true",
    RENDER_EXTERNAL_HOSTNAME: "skillconnect-api-unique.onrender.com",
    ALLOWED_HOSTS:
      "api.skillconnect.example,skillconnect-api-unique.onrender.com",
    PUBLIC_ORIGIN: "https://api.skillconnect.example",
  });
  assert.deepEqual(config.hosts, [
    "api.skillconnect.example",
    "skillconnect-api-unique.onrender.com",
  ]);
  assert.equal(config.publicOrigin, "https://api.skillconnect.example");
});

test("Render defaults do not bypass production safeguards", () => {
  assert.throws(
    () => configuration({ ...production, RENDER: "true" }),
    /ALLOWED_HOSTS/,
  );
  assert.throws(
    () =>
      configuration({
        ...production,
        RENDER_EXTERNAL_HOSTNAME: "untrusted.example",
      }),
    /ALLOWED_HOSTS/,
  );
  assert.throws(
    () => configuration({ ...production, ALLOWED_HOSTS: "*" }),
    /ALLOWED_HOSTS/,
  );
});
