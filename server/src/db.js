import { Pool } from 'pg';
import { config } from './config.js';

const pool = new Pool({
  connectionString: config.databaseUrl,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined
});

export async function query(text, params) {
  const client = await pool.connect();
  try {
    return await client.query(text, params);
  } finally {
    client.release();
  }
}

export async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function ensureTables() {
  await query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await query(`
    CREATE TABLE IF NOT EXISTS refresh_tokens (
      token TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await query(`
    CREATE OR REPLACE FUNCTION set_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
  `);

  await query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'set_users_updated_at'
      ) THEN
        CREATE TRIGGER set_users_updated_at
        BEFORE UPDATE ON users
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at_column();
      END IF;
    END $$;
  `);

  await query(`
    CREATE TABLE IF NOT EXISTS user_profiles (
      id SERIAL PRIMARY KEY,
      user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      display_name TEXT,
      phone_number TEXT,
      profile_picture_url TEXT,
      bio TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await query(`
    CREATE TABLE IF NOT EXISTS emergency_contacts (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      phone_number TEXT NOT NULL,
      relationship TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await query(`
    CREATE TABLE IF NOT EXISTS alerts_history (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      latitude DECIMAL(10, 8),
      longitude DECIMAL(11, 8),
      status TEXT NOT NULL DEFAULT 'pending',
      contacts_reached INTEGER DEFAULT 0,
      message TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await query(`
    CREATE TABLE IF NOT EXISTS location_share_sessions (
      id SERIAL PRIMARY KEY,
      token TEXT UNIQUE NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMPTZ NOT NULL,
      ended_at TIMESTAMPTZ,
      latest_latitude DECIMAL(10, 8),
      latest_longitude DECIMAL(11, 8),
      latest_accuracy_m DECIMAL(10, 2),
      last_location_at TIMESTAMPTZ,
      share_method TEXT,
      duration_minutes INTEGER NOT NULL
    );
  `);

  await query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'set_user_profiles_updated_at'
      ) THEN
        CREATE TRIGGER set_user_profiles_updated_at
        BEFORE UPDATE ON user_profiles
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at_column();
      END IF;
    END $$;
  `);

  await query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'set_emergency_contacts_updated_at'
      ) THEN
        CREATE TRIGGER set_emergency_contacts_updated_at
        BEFORE UPDATE ON emergency_contacts
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at_column();
      END IF;
    END $$;
  `);

  await query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'set_location_share_sessions_updated_at'
      ) THEN
        CREATE TRIGGER set_location_share_sessions_updated_at
        BEFORE UPDATE ON location_share_sessions
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at_column();
      END IF;
    END $$;
  `);

  await query(`
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      code_hash TEXT NOT NULL,
      channel TEXT NOT NULL DEFAULT 'email',
      expires_at TIMESTAMPTZ NOT NULL,
      used BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}
