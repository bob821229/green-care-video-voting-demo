const DEMO_STORAGE_KEY='green-care-voting-demo-v1';
const isDemo=location.hostname.endsWith('.github.io')||new URLSearchParams(location.search).has('demo');

const sessions=new Map();
let videosPromise;

function readStore(){
  try{return JSON.parse(localStorage.getItem(DEMO_STORAGE_KEY))||{progress:{},vote:null}}
  catch{return {progress:{},vote:null}}
}

function writeStore(store){localStorage.setItem(DEMO_STORAGE_KEY,JSON.stringify(store))}
function requestBody(options){try{return JSON.parse(options?.body||'{}')}catch{return {}}}
function activity(){return {state:'active',startsAt:'2026-01-01T00:00:00+08:00',endsAt:'2026-12-31T23:59:59+08:00'}}
function mockVotes(id){return 180+((id*347+id*id*29)%1220)}

async function loadVideos(){
  videosPromise??=fetch('./mock-videos.json').then((response)=>{
    if(!response.ok)throw new Error('無法載入展示資料。');
    return response.json();
  }).then((items)=>items.map((video)=>({...video,category:video.id<=15?'individual':'team'})));
  return videosPromise;
}

async function mockApi(url,options={}){
  const videos=await loadVideos();
  const store=readStore();
  const body=requestBody(options);

  if(url==='/api/bootstrap'){
    return {
      videos,
      vote:store.vote,
      progress:Object.entries(store.progress).map(([videoId,ratio])=>({videoId:Number(videoId),ratio})),
      activity:activity(),
      turnstileSiteKey:'',
      demo:true
    };
  }

  if(url==='/api/watch/start'){
    const sessionId=`demo-${Date.now()}-${body.videoId}`;
    sessions.set(sessionId,{videoId:Number(body.videoId),duration:Number(body.duration)||1});
    return {sessionId};
  }

  if(url==='/api/watch/progress'){
    const session=sessions.get(body.sessionId);
    if(!session)throw new Error('展示觀看工作階段已失效，請重新開啟影片。');
    const previous=Number(store.progress[session.videoId])||0;
    const ratio=Math.max(previous,Math.min(1,(Number(body.position)||0)/session.duration));
    store.progress[session.videoId]=ratio;
    writeStore(store);
    return {ratio,qualified:ratio>=.8};
  }

  if(url==='/api/vote'){
    if(store.vote)throw new Error('此瀏覽器已完成展示投票。');
    const session=sessions.get(body.sessionId);
    if(!session||Number(store.progress[session.videoId])<.8)throw new Error('觀看進度尚未達 80%。');
    store.vote={videoId:Number(body.videoId),status:'valid'};
    writeStore(store);
    return {status:'valid'};
  }

  if(url==='/api/results'){
    const voteId=Number(store.vote?.videoId)||0;
    const ranked=(category)=>videos.filter((video)=>video.category===category).map((video)=>({...video,votes:mockVotes(video.id)+(video.id===voteId?1:0)})).sort((a,b)=>b.votes-a.votes||a.id-b.id).map((video,index)=>({...video,rank:index+1}));
    return {published:false,preview:true,generatedAt:new Date().toISOString(),activity:activity(),groups:{individual:ranked('individual'),team:ranked('team')},demo:true};
  }

  throw new Error('展示模式不支援此操作。');
}

async function api(url,options={}){
  if(isDemo)return mockApi(url,options);
  const response=await fetch(url,{...options,headers:{'content-type':'application/json',...(options.headers||{})}});
  const body=await response.json().catch(()=>({}));
  if(!response.ok)throw new Error(body.error||body.message||'系統暫時無法處理。');
  return body;
}

window.votingApi={api,isDemo};
