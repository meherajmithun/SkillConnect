import { randomUUID } from "node:crypto";
import path from "node:path";
import { mkdir, writeFile, unlink } from "node:fs/promises";
import multer from "multer";
import sharp from "sharp";
import { ownProfile } from "./marketplace.js";
import { reject, text, find, paginate } from "./validation.js";

export function uploadRoutes(app, db, config, auth) {
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024, files: 1, fields: 2, fieldSize: 4000 },
  }).single("image");
  const view = (row, req) => ({
    id: row.id,
    title: row.title,
    description: row.description,
    image: row.image
      ? new URL(
          row.image,
          config.mediaBaseUrl || `${req.protocol}://${req.get("host")}/media/`,
        ).href
      : null,
  });
  async function image(file) {
    if (!file) return "";
    try {
      const metadata = await sharp(file.buffer, {
        limitInputPixels: 25000000,
      }).metadata();
      if (!["jpeg", "png", "webp"].includes(metadata.format))
        reject("Use a JPEG, PNG or WebP image.");
      const bytes = await sharp(file.buffer, { limitInputPixels: 25000000 })
        .rotate()
        .resize({
          width: 1600,
          height: 1600,
          fit: "inside",
          withoutEnlargement: true,
        })
        .jpeg({ quality: 85 })
        .toBuffer();
      const filename = `portfolio/${randomUUID()}.jpg`;
      await mkdir(path.join(config.mediaDir, "portfolio"), { recursive: true });
      await writeFile(path.join(config.mediaDir, filename), bytes, {
        flag: "wx",
      });
      return filename;
    } catch (error) {
      if (error.status) throw error;
      reject("Use a valid image smaller than 5 MB.");
    }
  }
  const removeImage = (filename) =>
    /^portfolio\/[\w/-]+\.(jpg|jpeg|png|webp)$/i.test(filename)
      ? unlink(path.join(config.mediaDir, filename)).catch(() => {})
      : Promise.resolve();
  app.get("/api/portfolio/", auth.authenticate, async (req, res) => {
    const rows = await db.read(async (tx) =>
      tx.all(
        "SELECT * FROM portfolio WHERE professional_id=? ORDER BY id DESC",
        [(await ownProfile(tx, req.user)).id],
      ),
    );
    const origin =
      config.mediaBaseUrl || `${req.protocol}://${req.get("host")}/media/`;
    res.json(
      paginate(
        rows.map((r) => ({
          ...r,
          image: r.image ? new URL(r.image, origin).href : null,
        })),
        req,
      ),
    );
  });
  app.post("/api/portfolio/", auth.authenticate, upload, async (req, res) => {
    await db.read((tx) => ownProfile(tx, req.user));
    const values = {
      title: text(req.body.title, "project title", 120),
      description: text(req.body.description ?? "", "description", 1000, true),
      image: "",
    };
    values.image = await image(req.file);
    let row;
    try {
      row = await db.transaction(async (tx) =>
        tx.insert("portfolio", {
          professional_id: (await ownProfile(tx, req.user)).id,
          ...values,
        }),
      );
    } catch (error) {
      if (values.image)
        await unlink(path.join(config.mediaDir, values.image)).catch(() => {});
      throw error;
    }
    res.status(201).json(view(row, req));
  });
  app.get("/api/portfolio/:id/", auth.authenticate, async (req, res) =>
    res.json(
      await db.read(async (tx) => {
        const pro = await ownProfile(tx, req.user),
          row = await find(tx, "portfolio", req.params.id);
        if (row.professional_id !== pro.id) reject("Not found.", 404);
        return view(row, req);
      }),
    ),
  );
  for (const method of ["put", "patch"])
    app[method](
      "/api/portfolio/:id/",
      auth.authenticate,
      upload,
      async (req, res) => {
        await db.read(async (tx) => {
          const pro = await ownProfile(tx, req.user),
            row = await find(tx, "portfolio", req.params.id);
          if (row.professional_id !== pro.id) reject("Not found.", 404);
        });
        const values = {};
        if ("title" in req.body || method === "put")
          values.title = text(req.body.title, "project title", 120);
        if ("description" in req.body || method === "put")
          values.description = text(
            req.body.description ?? "",
            "description",
            1000,
            true,
          );
        const filename = await image(req.file);
        if (filename) values.image = filename;
        let previous, row;
        try {
          row = await db.transaction(async (tx) => {
            const pro = await ownProfile(tx, req.user);
            previous = await find(tx, "portfolio", req.params.id);
            if (previous.professional_id !== pro.id) reject("Not found.", 404);
            return tx.update("portfolio", previous.id, values);
          });
        } catch (error) {
          if (filename) await removeImage(filename);
          throw error;
        }
        if (filename && previous.image) await removeImage(previous.image);
        res.json(view(row, req));
      },
    );
  app.delete("/api/portfolio/:id/", auth.authenticate, async (req, res) => {
    const row = await db.transaction(async (tx) => {
      const pro = await ownProfile(tx, req.user),
        work = await find(tx, "portfolio", req.params.id);
      if (work.professional_id !== pro.id) reject("Not found.", 404);
      await tx.query("DELETE FROM portfolio WHERE id=?", [work.id]);
      return work;
    });
    if (row.image) await removeImage(row.image);
    res.sendStatus(204);
  });
}
