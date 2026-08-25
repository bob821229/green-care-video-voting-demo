import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { createDatabase } from '../db.js';

if (process.env.NODE_ENV === 'production') {
  console.error('拒絕執行：正式環境不可產生 mock 票數。');
  process.exit(1);
}

const db = createDatabase(process.env.DB_PATH);
const videos = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'videos.json'), 'utf8'));
const now = new Date().toISOString();
const randomVotes = () => crypto.randomInt(120, 1401);

const clearPreviousMocks = db.transaction(() => {
  db.prepare("DELETE FROM risk_events WHERE device_id LIKE 'mock-result-%'").run();
  db.prepare("DELETE FROM votes WHERE device_id LIKE 'mock-result-%'").run();
  db.prepare("DELETE FROM watch_sessions WHERE device_id LIKE 'mock-result-%'").run();
  db.prepare("DELETE FROM devices WHERE id LIKE 'mock-result-%'").run();
});

const insertDevice = db.prepare('INSERT INTO devices(id,created_at,last_seen_at) VALUES(?,?,?)');
const insertWatch = db.prepare('INSERT INTO watch_sessions(id,device_id,video_id,duration,watched_seconds,last_position,last_ping_at,qualified_at,created_at) VALUES(?,?,?,?,?,?,?,?,?)');
const insertVote = db.prepare('INSERT INTO votes(device_id,video_id,category,watch_session_id,ip_hash,device_signal_hash,risk_score,status,created_at) VALUES(?,?,?,?,?,?,?,?,?)');

const totals = [];
const seed = db.transaction(() => {
  for (const video of videos) {
    const count = randomVotes();
    totals.push({ id: video.id, number: video.number, title: video.title, votes: count });
    for (let index = 0; index < count; index += 1) {
      const deviceId = `mock-result-${video.id}-${index}`;
      const watchId = `mock-watch-${video.id}-${index}`;
      insertDevice.run(deviceId, now, now);
      insertWatch.run(watchId, deviceId, video.id, 60, 60, 60, Date.now(), now, now);
      insertVote.run(deviceId, video.id, video.id <= 15 ? 'individual' : 'team', watchId, `mock-ip-${video.id}-${index}`, `mock-signal-${video.id}-${index}`, 0, 'valid', now);
    }
  }
});

clearPreviousMocks();
seed();
db.close();

const grandTotal = totals.reduce((sum, item) => sum + item.votes, 0);
console.log(`已建立 ${grandTotal.toLocaleString('zh-TW')} 張 mock 有效票。`);
for (const group of [totals.slice(0, 15), totals.slice(15)]) {
  console.log(group.sort((a, b) => b.votes - a.votes).map((item, index) => `${index + 1}. ${item.number} ${item.title}: ${item.votes.toLocaleString('zh-TW')} 票`).join('\n'));
  console.log('');
}
