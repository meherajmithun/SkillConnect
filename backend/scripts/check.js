import { readdir } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";

async function files(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...(await files(filename)));
    else if (filename.endsWith(".js")) result.push(filename);
  }
  return result;
}
for (const file of [
  ...(await files("src")),
  ...(await files("public")),
  ...(await files("test")),
]) {
  const result = spawnSync(process.execPath, ["--check", file], {
    stdio: "inherit",
  });
  if (result.status) process.exit(result.status);
}
console.log("JavaScript syntax checks passed.");
