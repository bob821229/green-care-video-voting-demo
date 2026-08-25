import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';

function createVotesTable(db) {
  db.exec(`
    CREATE TABLE votes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id TEXT NOT NULL REFERENCES devices(id), video_id INTEGER NOT NULL,
      category TEXT NOT NULL CHECK(category IN ('individual','team')),
      watch_session_id TEXT NOT NULL REFERENCES watch_sessions(id), ip_hash TEXT NOT NULL,
      device_signal_hash TEXT, risk_score INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'valid' CHECK(status IN ('valid','flagged','cancelled','void')),
      created_at TEXT NOT NULL, cancelled_at TEXT, replaced_by_vote_id INTEGER,
      voided_at TEXT, void_reason TEXT
    );
    CREATE UNIQUE INDEX idx_votes_active_work ON votes(device_id,video_id) WHERE status IN ('valid','flagged');
    CREATE INDEX idx_votes_device_group ON votes(device_id,category,status);
    CREATE INDEX idx_votes_video ON votes(video_id,status);
    CREATE INDEX idx_votes_ip ON votes(ip_hash,created_at);
  `);
}

function migrateVotes(db) {
  const existing=db.prepare("SELECT sql FROM sqlite_master WHERE type='table' AND name='votes'").get();
  if(!existing)return createVotesTable(db);
  const columns=new Set(db.prepare('PRAGMA table_info(votes)').all().map((row)=>row.name));
  if(columns.has('category')&&columns.has('cancelled_at'))return;
  db.transaction(()=>{
    db.exec('DROP INDEX IF EXISTS idx_votes_video; DROP INDEX IF EXISTS idx_votes_ip; DROP INDEX IF EXISTS idx_votes_device_group; DROP INDEX IF EXISTS idx_votes_active_work;');
    db.exec('ALTER TABLE votes RENAME TO votes_legacy');
    createVotesTable(db);
    db.exec(`INSERT INTO votes(id,device_id,video_id,category,watch_session_id,ip_hash,device_signal_hash,risk_score,status,created_at,voided_at,void_reason)
      SELECT id,device_id,video_id,CASE WHEN video_id<=15 THEN 'individual' ELSE 'team' END,watch_session_id,ip_hash,device_signal_hash,risk_score,status,created_at,voided_at,void_reason FROM votes_legacy;
      DROP TABLE votes_legacy;`);
  })();
}

export function createDatabase(filename=path.join(process.cwd(),'data','votes.db')) {
  if(filename!==':memory:')fs.mkdirSync(path.dirname(filename),{recursive:true});
  const db=new Database(filename);
  db.pragma('journal_mode = WAL'); db.pragma('foreign_keys = ON');
  db.exec(`
    CREATE TABLE IF NOT EXISTS devices (id TEXT PRIMARY KEY,created_at TEXT NOT NULL,last_seen_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS watch_sessions (
      id TEXT PRIMARY KEY,device_id TEXT NOT NULL REFERENCES devices(id),video_id INTEGER NOT NULL,
      duration REAL NOT NULL,watched_seconds REAL NOT NULL DEFAULT 0,last_position REAL NOT NULL DEFAULT 0,
      last_ping_at INTEGER NOT NULL,qualified_at TEXT,created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_watch_device ON watch_sessions(device_id,video_id);
    CREATE TABLE IF NOT EXISTS risk_events (id INTEGER PRIMARY KEY AUTOINCREMENT,device_id TEXT,ip_hash TEXT,kind TEXT NOT NULL,detail TEXT,created_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS audit_logs (id INTEGER PRIMARY KEY AUTOINCREMENT,action TEXT NOT NULL,target TEXT NOT NULL,detail TEXT,created_at TEXT NOT NULL);
  `);
  migrateVotes(db);
  return db;
}
