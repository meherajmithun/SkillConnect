const $ = (id) => document.getElementById(id);
let resource = "professionals";
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
function feedback(error) {
  $("feedback").textContent = error?.message || "";
}
async function api(path, method = "GET", body, retry = true) {
  const token = sessionStorage.getItem("access");
  const response = await fetch(`/api/${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (
    response.status === 401 &&
    retry &&
    sessionStorage.getItem("refresh") &&
    path !== "auth/login/"
  ) {
    const renewal = await fetch("/api/auth/refresh/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh: sessionStorage.getItem("refresh") }),
    });
    if (renewal.ok) {
      const pair = await renewal.json();
      sessionStorage.setItem("access", pair.access);
      sessionStorage.setItem("refresh", pair.refresh);
      return api(path, method, body, false);
    }
  }
  const data = await response.json();
  if (!response.ok) throw new Error(data.detail || "Request failed.");
  return data;
}
function button(label, task) {
  const element = document.createElement("button");
  element.type = "button";
  element.textContent = label;
  element.addEventListener("click", async () => {
    element.disabled = true;
    feedback();
    try {
      await task();
    } catch (error) {
      feedback(error);
    } finally {
      element.disabled = false;
    }
  });
  return element;
}
async function metrics() {
  const data = await api("analytics/");
  $("metrics").replaceChildren();
  for (const [key, value] of Object.entries(data)) {
    const item = document.createElement("span");
    item.textContent = `${key.replaceAll("_", " ")}: ${value}`;
    $("metrics").append(item);
  }
}
async function load() {
  feedback();
  const data = await api(`admin/${resource}/`);
  $("heading").textContent = resource[0].toUpperCase() + resource.slice(1);
  document
    .querySelectorAll("#tabs button")
    .forEach((b) =>
      b.setAttribute("aria-current", String(b.textContent === resource)),
    );
  $("add").hidden = !["categories", "areas", "packages"].includes(resource);
  const keys = data.results.length
    ? Object.keys(data.results[0]).filter(
        (k) => !["password", "user_id", "created_at", "updated_at"].includes(k),
      )
    : ["id"];
  $("columns").replaceChildren();
  const heading = document.createElement("tr");
  for (const key of [...keys, "Actions"]) {
    const th = document.createElement("th");
    th.textContent = key.replaceAll("_", " ");
    heading.append(th);
  }
  $("columns").append(heading);
  $("records").replaceChildren();
  for (const row of data.results) {
    const tr = document.createElement("tr");
    for (const key of keys) {
      const td = document.createElement("td");
      td.textContent =
        typeof row[key] === "object" && row[key] != null
          ? JSON.stringify(row[key])
          : String(row[key] ?? "");
      tr.append(td);
    }
    const actions = document.createElement("td");
    const toggle = (field, label) =>
      actions.append(
        button(label, async () => {
          await api(`admin/${resource}/${row.id}/`, "PATCH", {
            [field]: !Boolean(row[field]),
          });
          await refresh();
        }),
      );
    if (resource === "users")
      toggle("is_active", row.is_active ? "Deactivate" : "Activate");
    if (resource === "professionals")
      toggle("verified", row.verified ? "Unverify" : "Verify");
    if (resource === "reviews")
      toggle("visible", row.visible ? "Hide" : "Restore");
    if (resource === "reports")
      actions.append(
        button(row.resolved ? "Reopen" : "Resolve", async () => {
          const resolution = prompt("Resolution notes", row.resolution);
          if (resolution == null) return;
          await api(`admin/reports/${row.id}/`, "PATCH", {
            resolved: !Boolean(row.resolved),
            resolution,
          });
          await refresh();
        }),
      );
    if (resource === "promotions") {
      if (row.status === "pending")
        actions.append(
          button("Confirm received payment", async () => {
            if (
              !confirm("Has payment been received and independently verified?")
            )
              return;
            await api(`admin/promotions/${row.id}/confirm/`, "POST", {
              confirm: true,
            });
            await refresh();
          }),
        );
      if (row.status !== "cancelled")
        actions.append(
          button("Cancel", async () => {
            if (!confirm("Cancel this promotion?")) return;
            await api(`admin/promotions/${row.id}/cancel/`, "POST", {});
            await refresh();
          }),
        );
    }
    if (["categories", "areas", "packages"].includes(resource))
      actions.append(
        button("Edit", async () => {
          const fields =
            resource === "categories"
              ? ["name", "icon", "active"]
              : resource === "areas"
                ? ["name", "city", "latitude", "longitude"]
                : ["name", "days", "price", "active"];
          const values = {};
          for (const key of fields) {
            const answer = prompt(key, String(row[key]));
            if (answer == null) return;
            values[key] =
              key === "active"
                ? ["true", "1"].includes(answer)
                : ["days", "latitude", "longitude"].includes(key)
                  ? Number(answer)
                  : answer;
          }
          await api(`admin/${resource}/${row.id}/`, "PATCH", values);
          await refresh();
        }),
      );
    tr.append(actions);
    $("records").append(tr);
  }
}
async function refresh() {
  await metrics();
  await load();
}
async function enter() {
  const user = await api("me/");
  if (!user.is_staff) throw new Error("This account is not an administrator.");
  $("login").hidden = true;
  $("dashboard").hidden = false;
  $("logout").hidden = false;
  await refresh();
}
$("login").addEventListener("submit", async (event) => {
  event.preventDefault();
  feedback();
  const values = Object.fromEntries(new FormData(event.target));
  try {
    const pair = await api("auth/login/", "POST", values);
    sessionStorage.setItem("access", pair.access);
    sessionStorage.setItem("refresh", pair.refresh);
    await enter();
  } catch (error) {
    sessionStorage.clear();
    feedback(error);
  }
});
$("logout").addEventListener("click", async () => {
  try {
    await api("auth/logout/", "POST", {
      refresh: sessionStorage.getItem("refresh"),
    });
  } catch {}
  sessionStorage.clear();
  location.reload();
});
for (const name of resources)
  $("tabs").append(
    button(name, async () => {
      resource = name;
      await load();
    }),
  );
$("add").addEventListener("click", async () => {
  const fields =
    resource === "categories"
      ? ["name", "icon"]
      : resource === "areas"
        ? ["name", "city", "latitude", "longitude"]
        : ["name", "days", "price"];
  const values = {};
  for (const key of fields) {
    const answer = prompt(key);
    if (answer == null) return;
    values[key] = ["days", "latitude", "longitude"].includes(key)
      ? Number(answer)
      : answer;
  }
  try {
    await api(`admin/${resource}/`, "POST", values);
    await refresh();
  } catch (error) {
    feedback(error);
  }
});
if (sessionStorage.getItem("access"))
  enter().catch((error) => {
    sessionStorage.clear();
    feedback(error);
  });
