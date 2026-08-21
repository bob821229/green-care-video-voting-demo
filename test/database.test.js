import test from 'node:test';
import assert from 'node:assert/strict';
import { createDatabase } from '../db.js';

test('database enforces one vote per device', () => {
  const db = createDatabase(':memory:');
  const now = new Date().toISOString();
  db.prepare('INSERT INTO devices(id,created_at,last_seen_at) VALUES(?,?,?)').run('device-1', now, now);
  db.prepare('INSERT INTO watch_sessions(id,device_id,video_id,duration,last_ping_at,created_at,qualified_at) VALUES(?,?,?,?,?,?,?)').run('watch-1','device-1',1,100,Date.now(),now,now);
  const insert = db.prepare('INSERT INTO votes(device_id,video_id,watch_session_id,ip_hash,risk_score,status,created_at) VALUES(?,?,?,?,?,?,?)');
  insert.run('device-1',1,'watch-1','ip',0,'valid',now);
  assert.throws(() => insert.run('device-1',2,'watch-1','ip',0,'valid',now), /UNIQUE/);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM votes').get().count, 1);
  db.close();
});

test('voiding a vote preserves it for audit', () => {
  const db = createDatabase(':memory:');
  const now = new Date().toISOString();
  db.prepare('INSERT INTO devices(id,created_at,last_seen_at) VALUES(?,?,?)').run('device-1',now,now);
  db.prepare('INSERT INTO watch_sessions(id,device_id,video_id,duration,last_ping_at,created_at) VALUES(?,?,?,?,?,?)').run('watch-1','device-1',1,100,Date.now(),now);
  db.prepare('INSERT INTO votes(device_id,video_id,watch_session_id,ip_hash,risk_score,status,created_at) VALUES(?,?,?,?,?,?,?)').run('device-1',1,'watch-1','ip',80,'flagged',now);
  db.prepare("UPDATE votes SET status='void',void_reason=? WHERE device_id=?").run('異常集中投票','device-1');
  const vote=db.prepare('SELECT status,void_reason FROM votes WHERE device_id=?').get('device-1');
  assert.deepEqual(vote,{status:'void',void_reason:'異常集中投票'});
  db.close();
});

