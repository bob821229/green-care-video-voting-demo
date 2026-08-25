import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

test('vote API enforces quota and supports atomic replace and cancel',async()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'green-vote-'));
  process.env.NODE_ENV='test';process.env.DB_PATH=path.join(dir,'test.db');process.env.APP_SECRET='test-secret';process.env.ACTIVITY_START='2020-01-01T00:00:00+08:00';process.env.ACTIVITY_END='2099-01-01T00:00:00+08:00';
  const {app,db}=await import(`../server.js?api-test=${Date.now()}`),server=app.listen(0),base=`http://127.0.0.1:${server.address().port}`;
  try{
    const boot=await fetch(`${base}/api/bootstrap`),cookie=boot.headers.get('set-cookie').split(';')[0],deviceId=db.prepare('SELECT id FROM devices').get().id,now=new Date().toISOString();
    for(const videoId of [1,2,3,16])db.prepare('INSERT INTO watch_sessions(id,device_id,video_id,duration,watched_seconds,last_position,last_ping_at,qualified_at,created_at) VALUES(?,?,?,?,?,?,?,?,?)').run(`w${videoId}`,deviceId,videoId,100,80,80,Date.now(),now,now);
    const call=(url,method='POST',payload={})=>fetch(`${base}${url}`,{method,headers:{cookie,'content-type':'application/json'},body:method==='DELETE'?undefined:JSON.stringify({recaptchaToken:'test-pass',deviceSignal:'test-device',...payload})});
    const first=await call('/api/votes','POST',{videoId:1}),firstVote=await first.json();assert.equal(first.status,201);
    assert.equal((await call('/api/votes','POST',{videoId:2})).status,201);
    assert.equal((await call('/api/votes','POST',{videoId:3})).status,409);
    assert.equal((await call(`/api/votes/${firstVote.id}/replace`,'POST',{videoId:3})).status,201);
    const active=db.prepare("SELECT video_id videoId FROM votes WHERE status IN ('valid','flagged') ORDER BY video_id").all().map(r=>r.videoId);assert.deepEqual(active,[2,3]);
    const second=db.prepare("SELECT id FROM votes WHERE video_id=2 AND status='valid'").get();assert.equal((await call(`/api/votes/${second.id}`,'DELETE')).status,200);
    assert.equal(db.prepare("SELECT COUNT(*) count FROM votes WHERE status IN ('valid','flagged')").get().count,1);
    assert.equal(db.prepare("SELECT COUNT(*) count FROM votes WHERE status='cancelled'").get().count,2);
  }finally{await new Promise(resolve=>server.close(resolve));db.close();fs.rmSync(dir,{recursive:true,force:true})}
});
