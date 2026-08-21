import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';

export function createDatabase(filename = path.join(process.cwd(), 'data', 'votes.db')) {
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  const db = new Database(filename);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.exec(`
    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      last_seen_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS watch_sessions (
      id TEXT PRIMARY KEY,
      device_id TEXT NOT NULL REFERENCES devices(id),
      video_id INTEGER NOT NULL,
      duration REAL NOT NULL,
      watched_seconds REAL NOT NULL DEFAULT 0,
      last_position REAL NOT NULL DEFAULT 0,
      last_ping_at INTEGER NOT NULL,
      qualified_at TEXT,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_watch_device ON watch_sessions(device_id, video_id);
    CREATE TABLE IF NOT EXISTS votes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id TEXT NOT NULL UNIQUE REFERENCES devices(id),
      video_id INTEGER NOT NULL,
      watch_session_id TEXT NOT NULL REFERENCES watch_sessions(id),
      ip_hash TEXT NOT NULL,
      device_signal_hash TEXT,
      risk_score INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'valid' CHECK(status IN ('valid','flagged','void')),
      created_at TEXT NOT NULL,
      voided_at TEXT,
      void_reason TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_votes_video ON votes(video_id, status);
    CREATE INDEX IF NOT EXISTS idx_votes_ip ON votes(ip_hash, created_at);
    CREATE TABLE IF NOT EXISTS risk_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id TEXT,
      ip_hash TEXT,
      kind TEXT NOT NULL,
      detail TEXT,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      target TEXT NOT NULL,
      detail TEXT,
      created_at TEXT NOT NULL
    );
  `);
  return db;
}

