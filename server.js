import express from 'express';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createDatabase } from './db.js';

const root = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const db = createDatabase(process.env.DB_PATH);
const videos = JSON.parse(fs.readFileSync(path.join(root, 'videos.json'), 'utf8')).map((video) => ({
  ...video,
  category: video.category || (video.id <= 15 ? 'individual' : 'team')
}));
const videoIds = new Set(videos.map((v) => v.id));
const secret = process.env.APP_SECRET || 'development-only-secret-change-before-deploy';
const port = Number(process.env.PORT || 3000);
const activityStart = new Date(process.env.ACTIVITY_START || '2026-01-01T00:00:00+08:00');
const activityEnd = new Date(process.env.ACTIVITY_END || '2026-12-31T23:59:59+08:00');

if (process.env.NODE_ENV === 'production' && secret.startsWith('development-')) {
  throw new Error('Production requires APP_SECRET.');
}
if (process.env.TRUST_PROXY === '1') app.set('trust proxy', 1);
app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json({ limit: '20kb' }));
app.use(cookieParser());
app.use(express.static(path.join(root, 'public')));

const nowIso = () => new Date().toISOString();
const hash = (value) => crypto.createHmac('sha256', secret).update(String(value || '')).digest('hex');
const sign = (value) => `${value}.${hash(value)}`;
const unsign = (signed) => {
  if (!signed || !signed.includes('.')) return null;
  const index = signed.lastIndexOf('.');
  const value = signed.slice(0, index);
  const signature = signed.slice(index + 1);
  const expected = hash(value);
  return signature.length === expected.length && crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected)) ? value : null;
};

function getDevice(req, res) {
  let deviceId = unsign(req.cookies.vote_device);
  if (!deviceId) {
    deviceId = crypto.randomUUID();
    res.cookie('vote_device', sign(deviceId), { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', maxAge: 365 * 86400_000 });
  }
  db.prepare(`INSERT INTO devices(id,created_at,last_seen_at) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET last_seen_at=excluded.last_seen_at`).run(deviceId, nowIso(), nowIso());
  return deviceId;
}

function activityState() {
  const now = new Date();
  if (now < activityStart) return 'upcoming';
  if (now > activityEnd) return 'ended';
  return 'active';
}

async function verifyTurnstile(token, ip) {
  if (!process.env.TURNSTILE_SECRET_KEY) return process.env.NODE_ENV !== 'production';
  if (!token) return false;
  const body = new URLSearchParams({ secret: process.env.TURNSTILE_SECRET_KEY, response: token, remoteip: ip });
  const result = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', { method: 'POST', body });
  return Boolean((await result.json()).success);
}

app.get('/api/bootstrap', (req, res) => {
  const deviceId = getDevice(req, res);
  const vote = db.prepare('SELECT video_id AS videoId, status, created_at AS createdAt FROM votes WHERE device_id=?').get(deviceId);
  const progress = db.prepare('SELECT video_id AS videoId, MAX(watched_seconds / duration) AS ratio FROM watch_sessions WHERE device_id=? GROUP BY video_id').all(deviceId);
  res.json({ videos, vote: vote || null, progress, activity: { state: activityState(), startsAt: activityStart, endsAt: activityEnd }, turnstileSiteKey: process.env.TURNSTILE_SITE_KEY || '' });
});

app.post('/api/watch/start', (req, res) => {
  const deviceId = getDevice(req, res);
  const videoId = Number(req.body.videoId);
  const duration = Number(req.body.duration);
  if (!videoIds.has(videoId) || !Number.isFinite(duration) || duration < 10 || duration > 7200) return res.status(400).json({ error: '影片資料不正確。' });
  const id = crypto.randomUUID();
  db.prepare('INSERT INTO watch_sessions(id,device_id,video_id,duration,last_ping_at,created_at) VALUES(?,?,?,?,?,?)').run(id, deviceId, videoId, duration, Date.now(), nowIso());
  res.json({ sessionId: sign(id) });
});

app.post('/api/watch/progress', (req, res) => {
  const deviceId = getDevice(req, res);
  const id = unsign(req.body.sessionId);
  const session = id && db.prepare('SELECT * FROM watch_sessions WHERE id=? AND device_id=?').get(id, deviceId);
  if (!session) return res.status(404).json({ error: '觀看紀錄已失效，請重新播放。' });
  const position = Number(req.body.position);
  const playbackRate = Number(req.body.playbackRate);
  const clientPlaying = req.body.playing === true;
  const visible = req.body.visible === true;
  const wallDelta = Math.max(0, Math.min((Date.now() - session.last_ping_at) / 1000, 8));
  const positionDelta = position - session.last_position;
  const plausible = clientPlaying && visible && playbackRate > 0 && playbackRate <= 1.25 && positionDelta >= 0 && positionDelta <= wallDelta * 1.6 + 1;
  const credit = plausible ? Math.min(wallDelta, positionDelta + 0.5) : 0;
  const watched = Math.min(session.duration, session.watched_seconds + credit);
  const qualified = watched / session.duration >= 0.8;
  db.prepare('UPDATE watch_sessions SET watched_seconds=?,last_position=?,last_ping_at=?,qualified_at=COALESCE(qualified_at,?) WHERE id=?').run(watched, Number.isFinite(position) ? position : session.last_position, Date.now(), qualified ? nowIso() : null, id);
  res.json({ ratio: watched / session.duration, qualified });
});

app.post('/api/vote', async (req, res) => {
  const deviceId = getDevice(req, res);
  if (activityState() !== 'active') return res.status(403).json({ error: '目前不在投票期間。' });
  const id = unsign(req.body.sessionId);
  const videoId = Number(req.body.videoId);
  const session = id && db.prepare('SELECT * FROM watch_sessions WHERE id=? AND device_id=? AND video_id=?').get(id, deviceId, videoId);
  if (!session?.qualified_at || Date.now() - new Date(session.qualified_at).getTime() > 15 * 60_000) return res.status(403).json({ error: '請先觀看這支影片達 80%。' });
  if (!(await verifyTurnstile(req.body.turnstileToken, req.ip))) return res.status(403).json({ error: '驗證未完成，請重試。' });
  const ipHash = hash(req.ip);
  const deviceSignalHash = req.body.deviceSignal ? hash(req.body.deviceSignal) : null;
  const recentSameIp = db.prepare("SELECT COUNT(*) AS count FROM votes WHERE ip_hash=? AND created_at >= datetime('now','-10 minutes')").get(ipHash).count;
  const sameSignal = deviceSignalHash ? db.prepare('SELECT COUNT(*) AS count FROM votes WHERE device_signal_hash=?').get(deviceSignalHash).count : 0;
  const riskScore = Math.min(100, Math.max(0, (recentSameIp - 4) * 12 + sameSignal * 30));
  const status = riskScore >= 60 ? 'flagged' : 'valid';
  try {
    db.prepare('INSERT INTO votes(device_id,video_id,watch_session_id,ip_hash,device_signal_hash,risk_score,status,created_at) VALUES(?,?,?,?,?,?,?,?)').run(deviceId, videoId, id, ipHash, deviceSignalHash, riskScore, status, nowIso());
    if (riskScore > 0) db.prepare('INSERT INTO risk_events(device_id,ip_hash,kind,detail,created_at) VALUES(?,?,?,?,?)').run(deviceId, ipHash, 'vote_risk', JSON.stringify({ recentSameIp, sameSignal, riskScore }), nowIso());
    res.status(201).json({ ok: true, status });
  } catch (error) {
    if (error.code === 'SQLITE_CONSTRAINT_UNIQUE') return res.status(409).json({ error: '這台裝置已經完成投票。' });
    throw error;
  }
});

app.get('/api/results', (req, res) => {
  const explicitlyPublished = process.env.RESULTS_PUBLISHED === '1';
  const published = explicitlyPublished || activityState() === 'ended';
  const preview = process.env.NODE_ENV !== 'production' && !published;
  if (!published && !preview) {
    return res.status(403).json({
      published: false,
      activity: { state: activityState(), endsAt: activityEnd },
      message: '正式結果將於投票截止並完成票數確認後公布。'
    });
  }
  const counts = new Map(db.prepare("SELECT video_id AS videoId, COUNT(*) AS count FROM votes WHERE status='valid' GROUP BY video_id").all().map((row) => [row.videoId, row.count]));
  const ranked = (category) => videos
    .filter((video) => video.category === category)
    .map((video) => ({ ...video, votes: counts.get(video.id) || 0 }))
    .sort((a, b) => b.votes - a.votes || a.id - b.id)
    .map((video, index) => ({ ...video, rank: index + 1 }));
  res.json({
    published,
    preview,
    generatedAt: nowIso(),
    activity: { state: activityState(), startsAt: activityStart, endsAt: activityEnd },
    groups: { individual: ranked('individual'), team: ranked('team') }
  });
});

function requireAdmin(req, res, next) {
  const supplied = req.get('x-admin-key') || '';
  const expected = process.env.ADMIN_KEY || '';
  if (!expected || supplied.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(expected))) return res.status(401).json({ error: '未授權。' });
  next();
}

app.get('/api/admin/summary', requireAdmin, (req, res) => {
  const totals = db.prepare("SELECT video_id AS videoId, status, COUNT(*) AS count FROM votes GROUP BY video_id,status ORDER BY video_id").all();
  const flagged = db.prepare("SELECT id,video_id AS videoId,risk_score AS riskScore,status,created_at AS createdAt FROM votes WHERE status!='valid' ORDER BY created_at DESC LIMIT 200").all();
  res.json({ totals, flagged });
});

app.post('/api/admin/votes/:id/void', requireAdmin, (req, res) => {
  const reason = String(req.body.reason || '').trim().slice(0, 300);
  if (!reason) return res.status(400).json({ error: '請填寫作廢原因。' });
  const result = db.prepare("UPDATE votes SET status='void',voided_at=?,void_reason=? WHERE id=? AND status!='void'").run(nowIso(), reason, req.params.id);
  if (!result.changes) return res.status(404).json({ error: '找不到可作廢的票。' });
  db.prepare('INSERT INTO audit_logs(action,target,detail,created_at) VALUES(?,?,?,?)').run('void_vote', `vote:${req.params.id}`, reason, nowIso());
  res.json({ ok: true });
});

app.use((error, req, res, next) => {
  console.error(error);
  res.status(500).json({ error: '系統暫時無法處理，請稍後再試。' });
});

if (process.env.NODE_ENV !== 'test') app.listen(port, () => console.log(`Voting site: http://localhost:${port}`));
export { app };
