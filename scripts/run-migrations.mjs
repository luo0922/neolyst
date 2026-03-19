/**
 * Execute migrations via Supabase postgres-meta API (self-hosted)
 *
 * Usage (from web/ directory):
 *   pnpm run db:migrate
 */

import { readdir, readFile } from "fs/promises";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = resolve(__dirname, "../supabase/migrations");

// Load env
const envPath = resolve(__dirname, "../web/.env");
for (const line of (await readFile(envPath, "utf8")).split("\n")) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith("#")) continue;
  const eqIdx = trimmed.indexOf("=");
  if (eqIdx < 0) continue;
  const key = trimmed.slice(0, eqIdx);
  const value = trimmed.slice(eqIdx + 1);
  if (!process.env[key]) process.env[key] = value;
}

const PG_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const PG_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!PG_URL || !PG_KEY) {
  console.error("Error: NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set");
  process.exit(1);
}

const PG_QUERY_URL = `${PG_URL}/pg/query`;

// Ensure schema_migrations table exists
async function ensureMigrationsTable() {
  await fetch(PG_QUERY_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: PG_KEY },
    body: JSON.stringify({
      query: `
        create table if not exists public.schema_migrations (
          version varchar(255) primary key,
          inserted_at timestamptz not null default now()
        );
      `,
    }),
  });
}

// Get already applied migrations
async function getAppliedMigrations() {
  try {
    const res = await fetch(PG_QUERY_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: PG_KEY },
      body: JSON.stringify({ query: "SELECT version FROM public.schema_migrations" }),
    });
    const rows = await res.json();
    return new Set(Array.isArray(rows) ? rows.map((r) => r.version) : []);
  } catch {
    return new Set();
  }
}

// Execute a single migration
async function runMigration(sql, version) {
  const res = await fetch(PG_QUERY_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: PG_KEY },
    body: JSON.stringify({ query: sql }),
  });

  const text = await res.text();
  if (res.ok && !text.startsWith("{")) return { success: true };

  // Parse error
  try {
    const err = JSON.parse(text);
    if (err.code === "42P07" || err.code === "42710" || err.code === "23505") {
      return { success: true, skipped: true }; // Already exists
    }
    return { success: false, error: err.message || text };
  } catch {
    return { success: false, error: text };
  }
}

// Record migration as applied
async function recordMigration(version) {
  await fetch(PG_QUERY_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: PG_KEY },
    body: JSON.stringify({
      query: `INSERT INTO public.schema_migrations (version) VALUES ('${version}') ON CONFLICT DO NOTHING`,
    }),
  });
}

async function main() {
  console.log(`Supabase URL: ${PG_URL}\n`);

  await ensureMigrationsTable();
  const applied = await getAppliedMigrations();

  const files = (await readdir(MIGRATIONS_DIR))
    .filter((f) => f.endsWith(".sql"))
    .sort();

  let appliedCount = 0;
  let skippedCount = 0;

  for (const file of files) {
    const version = file.replace(".sql", "");

    if (applied.has(version)) {
      console.log(`  SKIP  ${file}`);
      skippedCount++;
      continue;
    }

    console.log(`  RUN   ${file}`);
    const sql = await readFile(resolve(MIGRATIONS_DIR, file), "utf8");
    const result = await runMigration(sql, version);

    if (result.success) {
      await recordMigration(version);
      if (result.skipped) {
        console.log(`        -> SKIPPED (already exists)`);
      } else {
        console.log(`        -> OK`);
      }
      appliedCount++;
    } else {
      console.error(`        -> ERROR: ${result.error}`);
      process.exit(1);
    }
  }

  console.log(`\nDone! Applied: ${appliedCount}, Skipped: ${skippedCount}`);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
