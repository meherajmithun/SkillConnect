import { configuration } from "./config.js";
import { openDatabase } from "./db.js";
import { createApp } from "./app.js";

const config = configuration();
const db = await openDatabase(config);
await db.migrate();
const server = createApp(db, config).listen(config.port, config.host, () =>
  console.log(
    `SkillConnect Node.js API listening on ${config.host}:${config.port}`,
  ),
);
let closing = false;
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => {
    if (closing) return;
    closing = true;
    server.close(async () => {
      await db.close();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  });
