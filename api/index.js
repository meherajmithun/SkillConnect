import { configuration } from "../backend/src/config.js";
import { openDatabase } from "../backend/src/db.js";
import { createApp } from "../backend/src/app.js";
import { initializeCatalogue } from "../backend/src/catalogue.js";

let initializing;

async function application() {
  if (!initializing) {
    initializing = (async () => {
      const config = configuration({ ...process.env, NODE_ENV: "production" });
      const db = await openDatabase(config);
      await db.migrate();
      await initializeCatalogue(db);
      return createApp(db, config);
    })().catch((error) => {
      initializing = undefined;
      throw error;
    });
  }
  return initializing;
}

export default async function handler(req, res) {
  try {
    const app = await application();
    return app(req, res);
  } catch (error) {
    console.error("SkillConnect API initialization failed:", error.message);
    if (!res.headersSent) {
      res.status(500).json({
        detail:
          "The API could not start. Check the Vercel database and environment variables.",
      });
    }
  }
}
