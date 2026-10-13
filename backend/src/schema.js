// One portable relational schema for PostgreSQL and local SQLite.
export function schema(postgres) {
  const id = postgres
    ? "SERIAL PRIMARY KEY"
    : "INTEGER PRIMARY KEY AUTOINCREMENT";
  return `
    CREATE TABLE IF NOT EXISTS users (
      id ${id}, username TEXT NOT NULL UNIQUE, email TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL, first_name TEXT NOT NULL DEFAULT '', last_name TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '', role TEXT NOT NULL CHECK(role IN ('customer','professional')),
      is_staff INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1,
      email_verified INTEGER NOT NULL DEFAULT 0, session_version INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS unique_email_lower ON users(LOWER(email));
    CREATE TABLE IF NOT EXISTS categories (id ${id}, name TEXT NOT NULL UNIQUE, icon TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1);
    CREATE TABLE IF NOT EXISTS areas (id ${id}, name TEXT NOT NULL UNIQUE, city TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL);
    CREATE TABLE IF NOT EXISTS professionals (
      id ${id}, user_id INTEGER NOT NULL UNIQUE REFERENCES users(id), business_name TEXT NOT NULL,
      bio TEXT NOT NULL DEFAULT '', skills TEXT NOT NULL DEFAULT '', experience_years INTEGER NOT NULL DEFAULT 0,
      available INTEGER NOT NULL DEFAULT 1, schedule_enabled INTEGER NOT NULL DEFAULT 0,
      verified INTEGER NOT NULL DEFAULT 0, starting_price TEXT NOT NULL DEFAULT '0.00',
      latitude REAL, longitude REAL, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS professional_categories (
      professional_id INTEGER NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
      category_id INTEGER NOT NULL REFERENCES categories(id), PRIMARY KEY(professional_id, category_id)
    );
    CREATE TABLE IF NOT EXISTS professional_areas (
      professional_id INTEGER NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
      area_id INTEGER NOT NULL REFERENCES areas(id), PRIMARY KEY(professional_id, area_id)
    );
    CREATE TABLE IF NOT EXISTS portfolio (
      id ${id}, professional_id INTEGER NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
      title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', image TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS slots (
      id ${id}, professional_id INTEGER NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
      starts_at TEXT NOT NULL, ends_at TEXT NOT NULL, CHECK(ends_at > starts_at)
    );
    CREATE TABLE IF NOT EXISTS quotes (
      id ${id}, customer_id INTEGER NOT NULL REFERENCES users(id), professional_id INTEGER NOT NULL REFERENCES professionals(id),
      category_id INTEGER NOT NULL REFERENCES categories(id), area_id INTEGER NOT NULL REFERENCES areas(id),
      details TEXT NOT NULL, amount TEXT, response TEXT NOT NULL DEFAULT '', revision INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS bookings (
      id ${id}, customer_id INTEGER NOT NULL REFERENCES users(id), professional_id INTEGER NOT NULL REFERENCES professionals(id),
      category_id INTEGER NOT NULL REFERENCES categories(id), area_id INTEGER NOT NULL REFERENCES areas(id),
      scheduled_at TEXT NOT NULL, duration_minutes INTEGER NOT NULL CHECK(duration_minutes BETWEEN 30 AND 480),
      slot_id INTEGER REFERENCES slots(id), quote_id INTEGER UNIQUE REFERENCES quotes(id), agreed_price TEXT, agreed_terms TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL, details TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('pending','accepted','rejected','completed','cancelled')), created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS booking_schedule ON bookings(professional_id, status, scheduled_at);
    CREATE TABLE IF NOT EXISTS reviews (
      id ${id}, booking_id INTEGER NOT NULL UNIQUE REFERENCES bookings(id), rating INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5),
      comment TEXT NOT NULL, visible INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS packages (id ${id}, name TEXT NOT NULL, days INTEGER NOT NULL CHECK(days BETWEEN 1 AND 365), price TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1);
    CREATE TABLE IF NOT EXISTS promotions (
      id ${id}, professional_id INTEGER NOT NULL REFERENCES professionals(id), package_id INTEGER NOT NULL REFERENCES packages(id),
      category_id INTEGER NOT NULL REFERENCES categories(id), area_id INTEGER NOT NULL REFERENCES areas(id), price_paid TEXT NOT NULL,
      duration_days INTEGER NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','paid','cancelled')), starts_at TEXT, expires_at TEXT, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS notifications (
      id ${id}, user_id INTEGER NOT NULL REFERENCES users(id), message TEXT NOT NULL,
      read INTEGER NOT NULL DEFAULT 0, push_sent INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS reports (
      id ${id}, reporter_id INTEGER NOT NULL REFERENCES users(id), professional_id INTEGER NOT NULL REFERENCES professionals(id),
      reason TEXT NOT NULL, resolved INTEGER NOT NULL DEFAULT 0, resolution TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS devices (id ${id}, user_id INTEGER NOT NULL REFERENCES users(id), token TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS challenges (
      id ${id}, user_id INTEGER NOT NULL REFERENCES users(id), purpose TEXT NOT NULL, email TEXT NOT NULL,
      code_hash TEXT NOT NULL, expires_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, used INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS refresh_sessions (jti TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), expires_at TEXT NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE IF NOT EXISTS messages (
      id ${id}, booking_id INTEGER REFERENCES bookings(id), quote_id INTEGER REFERENCES quotes(id),
      sender_id INTEGER NOT NULL REFERENCES users(id), body TEXT NOT NULL, read_at TEXT, created_at TEXT NOT NULL,
      CHECK((booking_id IS NULL AND quote_id IS NOT NULL) OR (booking_id IS NOT NULL AND quote_id IS NULL))
    );
    CREATE TABLE IF NOT EXISTS payments (
      id ${id}, promotion_id INTEGER NOT NULL REFERENCES promotions(id), transaction_id TEXT NOT NULL UNIQUE,
      amount TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('initiating','pending','paid','failed','review')),
      gateway_url TEXT NOT NULL DEFAULT '', session_key TEXT NOT NULL DEFAULT '', validation_id TEXT NOT NULL DEFAULT '', sandbox INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS push_deliveries (
      id ${id}, notification_id INTEGER NOT NULL REFERENCES notifications(id), device_id INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
      sent_at TEXT, attempts INTEGER NOT NULL DEFAULT 0, retry_at TEXT NOT NULL, UNIQUE(notification_id,device_id)
    );
    CREATE TABLE IF NOT EXISTS rate_limits (key TEXT PRIMARY KEY, window_at TEXT NOT NULL, count INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL);
    INSERT INTO schema_migrations (version,applied_at) VALUES (1,'${new Date().toISOString()}') ON CONFLICT(version) DO NOTHING;
  `;
}
