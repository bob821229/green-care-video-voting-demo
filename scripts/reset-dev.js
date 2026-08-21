import { createDatabase } from '../db.js';

if (process.env.NODE_ENV === 'production') {
  console.error('拒絕執行：正式環境不可使用測試資料重設指令。');
  process.exit(1);
}

const db = createDatabase(process.env.DB_PATH);
const reset = db.transaction(() => {
  db.prepare('DELETE FROM audit_logs').run();
  db.prepare('DELETE FROM risk_events').run();
  db.prepare('DELETE FROM votes').run();
  db.prepare('DELETE FROM watch_sessions').run();
  db.prepare('DELETE FROM devices').run();
});

reset();
db.close();
console.log('已清除本機測試票、觀看紀錄及裝置鎖定。重新整理網頁即可再次測試。');
