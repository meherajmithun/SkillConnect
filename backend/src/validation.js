export class HttpError extends Error {
  constructor(status, detail) {
    super(detail);
    this.status = status;
  }
}
export const reject = (message, status = 400) => {
  throw new HttpError(status, message);
};
export const timestamp = () => new Date().toISOString();
export function text(value, label, max = 2000, optional = false) {
  if (
    typeof value !== "string" ||
    value.length > max ||
    (!optional && !value.trim())
  )
    reject(`Enter ${label} (up to ${max} characters).`);
  return value.trim();
}
export function integer(value, label, min = 1, max = Number.MAX_SAFE_INTEGER) {
  if (
    (typeof value !== "number" && typeof value !== "string") ||
    value === "" ||
    !Number.isSafeInteger(Number(value)) ||
    Number(value) < min ||
    Number(value) > max
  )
    reject(`Use a valid ${label}.`);
  return Number(value);
}
export function bool(value, label) {
  if (typeof value !== "boolean") reject(`Use true or false for ${label}.`);
  return Number(value);
}
export function amount(value, min = 0) {
  if (
    (typeof value !== "string" && typeof value !== "number") ||
    !/^\d+(\.\d{1,2})?$/.test(String(value)) ||
    Number(value) < min ||
    Number(value) > 99999999.99
  )
    reject("Enter a valid BDT amount with at most two decimal places.");
  return Number(value).toFixed(2);
}
export function email(value) {
  const result = text(value, "email address", 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result))
    reject("Enter a valid email address.");
  return result;
}
export function date(value, label) {
  if (
    typeof value !== "string" ||
    !/(Z|[+-]\d\d:\d\d)$/.test(value) ||
    !Number.isFinite(Date.parse(value))
  )
    reject(`Use a timezone-aware ${label}.`);
  return new Date(value).toISOString();
}
export async function find(db, table, id) {
  const row = await db.one(`SELECT * FROM ${table} WHERE id=?`, [
    integer(id, "item ID"),
  ]);
  if (!row) reject("Not found.", 404);
  return row;
}
export function publicUser(user) {
  return Object.fromEntries(
    [
      "id",
      "username",
      "email",
      "first_name",
      "last_name",
      "phone",
      "role",
      "is_staff",
      "email_verified",
    ].map((key) => [
      key,
      ["is_staff", "email_verified"].includes(key)
        ? Boolean(user[key])
        : user[key],
    ]),
  );
}
export function paginate(rows, req) {
  const page = integer(req.query.page ?? 1, "page");
  const offset = (page - 1) * 30;
  const base = new URL(req.path, "https://placeholder.invalid");
  for (const [key, value] of Object.entries(req.query))
    base.searchParams.set(key, String(value));
  const link = (number) => {
    base.searchParams.set("page", number);
    return `${req.protocol}://${req.get("host")}${base.pathname}${base.search}`;
  };
  return {
    count: rows.length,
    results: rows.slice(offset, offset + 30),
    next: offset + 30 < rows.length ? link(page + 1) : null,
    previous: page > 1 ? link(page - 1) : null,
  };
}
