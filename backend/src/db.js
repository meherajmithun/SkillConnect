import { DatabaseSync } from "node:sqlite";
import { mkdirSync } from "node:fs";
import path from "node:path";
import pg from "pg";
import { schema } from "./schema.js";

function connection(run, postgres) {
  const execute = async (sql, params = []) => {
    let index = 0;
    return run(
      postgres ? sql.replaceAll("?", () => `$${++index}`) : sql,
      params,
    );
  };
  return {
    postgres,
    query: execute,
    all: async (sql, params) => (await execute(sql, params)).rows,
    one: async (sql, params) => (await execute(sql, params)).rows[0],
    insert: async (table, values) => {
      const keys = Object.keys(values);
      return (
        await execute(
          `INSERT INTO ${table} (${keys.join(",")}) VALUES (${keys.map(() => "?").join(",")}) RETURNING *`,
          Object.values(values),
        )
      ).rows[0];
    },
    update: async (table, id, values) => {
      const keys = Object.keys(values);
      if (!keys.length)
        return (await execute(`SELECT * FROM ${table} WHERE id=?`, [id]))
          .rows[0];
      return (
        await execute(
          `UPDATE ${table} SET ${keys.map((k) => `${k}=?`).join(",")} WHERE id=? RETURNING *`,
          [...Object.values(values), id],
        )
      ).rows[0];
    },
  };
}

export async function openDatabase(config) {
  const postgres = Boolean(config.databaseUrl || config.postgres);
  const pool = postgres
    ? new pg.Pool({
        ...(config.databaseUrl
          ? { connectionString: config.databaseUrl }
          : config.postgres),
        ...(config.databaseSsl ? { ssl: { rejectUnauthorized: true } } : {}),
      })
    : null;
  if (!postgres && config.sqlitePath !== ":memory:")
    mkdirSync(path.dirname(config.sqlitePath), { recursive: true });
  const sqlite = postgres ? null : new DatabaseSync(config.sqlitePath);
  sqlite?.exec(
    "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;",
  );
  const runSqlite = async (sql, params = []) => {
    const statement = sqlite.prepare(sql);
    if (/^\s*(SELECT|WITH)|RETURNING\s/i.test(sql))
      return { rows: statement.all(...params) };
    const result = statement.run(...params);
    return { rows: [], rowCount: Number(result.changes) };
  };
  const base = connection(
    postgres ? (sql, params) => pool.query(sql, params) : runSqlite,
    postgres,
  );
  let tail = Promise.resolve();
  const enqueue = (task) => {
    const result = tail.then(task);
    tail = result.catch(() => {});
    return result;
  };
  return {
    ...base,
    migrate: async () => {
      if (postgres) await pool.query(schema(true));
      else sqlite.exec(schema(false));
    },
    read: (task) => (postgres ? task(base) : enqueue(() => task(base))),
    transaction: (task) => {
      const perform = async () => {
        const client = postgres ? await pool.connect() : null;
        const tx = postgres
          ? connection((sql, params) => client.query(sql, params), true)
          : base;
        try {
          await tx.query(postgres ? "BEGIN" : "BEGIN IMMEDIATE");
          // Serialize marketplace writes across processes for overlap/idempotency checks.
          // A single short transaction lock is appropriate for this small marketplace.
          if (postgres) await tx.query("SELECT pg_advisory_xact_lock(824927)");
          const value = await task(tx);
          await tx.query("COMMIT");
          return value;
        } catch (error) {
          await tx.query("ROLLBACK");
          throw error;
        } finally {
          client?.release();
        }
      };
      return postgres ? perform() : enqueue(perform);
    },
    close: async () => {
      await tail;
      if (pool) await pool.end();
      else sqlite.close();
    },
  };
}
