# SkillConnect database implementation plan

## Objective

Move the backend from a single bootstrap schema to a versioned, reviewable
database evolution process that is safe for both local SQLite development and
deployed PostgreSQL. The plan should preserve existing data, support repeatable
deployments, and provide enough observability to diagnose migration or query
performance problems.

## Current state

- `backend/src/schema.js` contains the complete schema in one
  `CREATE TABLE IF NOT EXISTS` script.
- `backend/src/db.js` exposes PostgreSQL and SQLite adapters and runs the schema
  through `db.migrate()`.
- `schema_migrations` exists and records version `1`, but there is no migration
  runner for versions after the initial schema.
- The API uses transactions for marketplace writes. PostgreSQL transactions
  currently take one advisory lock for overlap and idempotency checks.
- Local development uses SQLite; deployment and CI also exercise PostgreSQL.
- The API already depends on indexes for booking schedules, but discovery and
  related-resource loading should be measured before adding more indexes.

## Target design

### Migration layout

Create a migration directory with ordered, immutable files:

```text
backend/migrations/
  001_initial_schema.js
  002_<short_description>.js
  003_<short_description>.js
```

Each migration exports:

```js
export const version = 2;
export const description = "Add ...";
export async function up(db) {}
```

Migrations must be append-only. Once a migration has run in a shared
environment, edit only a new migration rather than changing the old file.

### Migration metadata

Extend `schema_migrations` with enough information to audit execution:

- `version` as the primary key.
- `description`.
- `applied_at`.
- Optional `execution_ms` and `checksum` if implementation effort is
  reasonable.

The runner must:

1. Read applied versions.
2. Execute pending migrations in ascending order.
3. Run each migration in a transaction where the database supports it.
4. Record the migration only after success.
5. Fail startup and deployment when a migration fails; never continue with a
   partially upgraded schema.
6. Be safe to run repeatedly and concurrently during deployment.

For PostgreSQL, use a short advisory lock dedicated to migrations. For SQLite,
retain the existing serialized access and `BEGIN IMMEDIATE` behavior.

### Compatibility rules

Every schema change must be reviewed against both database engines:

- Use the adapter’s `?` placeholders rather than database-specific parameter
  syntax in application queries.
- Keep shared types and constraints portable unless a PostgreSQL-only feature
  has a documented SQLite fallback.
- Prefer additive changes first: add nullable columns, backfill, update code,
  then enforce stricter constraints in a later migration.
- Avoid table rewrites or long-running locks during application startup.
- For PostgreSQL indexes on large tables, consider concurrent index creation and
  document the transaction limitation.
- Keep SQLite migration behavior deterministic for fresh databases and imported
  databases.

## Implementation phases

### Phase 1: Freeze and verify the baseline

1. Capture the current schema as migration `001_initial_schema`.
2. Keep the existing schema version as the baseline for databases already
   initialized by the application.
3. Add tests for:
   - Fresh SQLite initialization.
   - Fresh PostgreSQL initialization.
   - Re-running migrations with no pending work.
   - Refusing an unknown or skipped migration version.
   - Preserving representative existing users, bookings, reviews and media
     references.
4. Document that migrations do not import or modify portfolio files.

**Exit criteria:** fresh and existing databases reach the same logical schema,
and a second migration run makes no changes.

### Phase 2: Build the migration runner

1. Extract migration execution from the monolithic `schema.js` path.
2. Add a dedicated migration module, for example
   `backend/src/migrations.js`.
3. Make `npm run migrate` the explicit migration command.
4. Keep server startup migration behavior temporarily, but make it call the
   same runner so local startup and deployment cannot diverge.
5. Add clear logs for applied, skipped and failed versions without logging
   credentials or personal data.
6. Add a migration test fixture that creates an old-version database and
   upgrades it to the latest version.

**Exit criteria:** CI can upgrade a database from the baseline to the latest
version on both SQLite and PostgreSQL.

### Phase 3: Add the first real incremental migration

Use the first production-relevant schema change to validate the process rather
than adding a no-op migration. Candidate work should be selected from measured
needs, such as:

- indexes for professional discovery filters and ordering;
- indexes for notification/message pagination;
- columns needed for durable media metadata;
- fields needed for payment reconciliation or audit history.

For each change:

1. Write the migration and update the schema documentation.
2. Add or update application queries.
3. Backfill existing rows in bounded batches if needed.
4. Add constraints only after existing data satisfies them.
5. Test rollback or the documented forward-repair procedure.
6. Measure query plans before and after the change.

Do not add speculative indexes. Record the query, expected access pattern,
measured improvement and write/storage cost in the migration pull request.

### Phase 4: Improve query scalability

Prioritize discovery and high-volume list endpoints:

1. Capture representative PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` plans for
   professional search, bookings, messages, notifications and reviews.
2. Move filtering, sorting and pagination into SQL where the endpoint currently
   loads related records repeatedly or filters in application code.
3. Replace repeated per-row queries with joins or batched lookups.
4. Add composite indexes only for confirmed predicates and sort orders.
5. Ensure every list endpoint has deterministic ordering and a bounded page
   size.
6. Re-run the existing API tests and add regression tests for pagination,
   ownership filtering and result ordering.

The PostgreSQL advisory lock should remain unchanged until concurrency tests
show contention. If contention is demonstrated, narrow locking around the
specific booking, slot or payment invariant and prove that overlap and
idempotency protections still hold.

### Phase 5: Backups, restore and operational checks

1. Define PostgreSQL backup frequency, retention and encryption requirements for
   the deployment environment.
2. Add a documented restore drill using a disposable database.
3. Verify that database backups and portfolio media backups can be restored
   together; database rows alone do not restore uploaded files.
4. Add a deployment preflight that checks:
   - database connectivity;
   - current migration version;
   - pending migrations;
   - backup freshness where the hosting platform exposes it.
5. Add monitoring for migration failures, connection-pool exhaustion, slow
   queries and database storage growth.

## Deployment procedure

1. Take a verified backup before applying schema changes.
2. Deploy code containing migrations and backward-compatible query changes.
3. Run `npm run migrate` against the target database.
4. Confirm the latest migration version and `/api/health/`.
5. Exercise authentication, discovery, booking creation and one staff read
   path with a staging or smoke-test account.
6. Monitor error rate and database latency during the rollout.
7. Remove compatibility code only in a later release after all instances have
   upgraded.

For multi-instance PostgreSQL deployments, run migrations as a single release
step rather than once per web process. Keep application startup checks
idempotent so a restart can verify the schema without rerunning completed
migrations.

## Rollback policy

Prefer forward-compatible rollbacks:

- Deploy code that can read both the old and new schema.
- If the application release must be reverted, leave additive migrations in
  place when they are harmless.
- Use a new migration to repair or remove data rather than editing migration
  history.
- Restore a database backup only for destructive or unrecoverable failures,
  after stopping writes and documenting the data-loss window.

Every migration plan must state whether rollback is:

1. code-only;
2. a forward repair migration; or
3. a backup restore.

## Testing checklist

- `npm run check`
- `npm test` with SQLite
- `TEST_DATABASE_URL=... npm test` with PostgreSQL
- Fresh database migration
- Upgrade from the previous production version
- Repeated migration execution
- Migration failure leaves no recorded success row
- Foreign keys, unique constraints and booking overlap behavior remain intact
- Existing API response shapes remain unchanged
- Query plans and endpoint latency are recorded for any performance migration

## Recommended first implementation

Start with the migration runner and baseline capture, then add a measured
discovery/list-query migration. This creates the safety mechanism needed for
all later database work without changing marketplace behavior prematurely.
After that, address durable backups and media/database restore as part of the
deployment-readiness work.
