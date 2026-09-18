import type { Bootstrap, Category, Results, Video, Vote, WatchProgress } from './types'
import { assetPath } from './paths'

type DemoState={votes:Vote[];progress:WatchProgress[]}
type DemoSession={videoId:number;duration:number;watchedSeconds:number;lastPosition:number}

const storageKey='greencare-vue-demo-v2'
const sessions=new Map<string,DemoSession>()
let videosPromise:Promise<Video[]>|undefined

function loadState():DemoState{
  try{return JSON.parse(localStorage.getItem(storageKey)||'') as DemoState}catch{return {votes:[],progress:[]}}
}
function saveState(state:DemoState){localStorage.setItem(storageKey,JSON.stringify(state))}
function body(init?:RequestInit){return init?.body?JSON.parse(String(init.body)) as Record<string,unknown>:{} }
function category(videoId:number):Category{return videoId<=15?'individual':'team'}
function remaining(state:DemoState,group:Category){return Math.max(0,2-state.votes.filter(v=>v.category===group).length)}

async function videos(){
  videosPromise??=fetch(assetPath('mock-videos.json')).then(async response=>{
    if(!response.ok)throw new Error('Demo 作品資料載入失敗。')
    return (await response.json() as Omit<Video,'category'>[]).map(video=>({...video,category:category(video.id)}))
  })
  return videosPromise
}

async function bootstrap():Promise<Bootstrap>{
  const state=loadState()
  return {videos:await videos(),votes:state.votes,progress:state.progress,limits:{individual:2,team:2},remaining:{individual:remaining(state,'individual'),team:remaining(state,'team')},activity:{state:'active',startsAt:'2026-10-12T02:00:00Z',endsAt:'2026-10-23T09:00:00Z'},recaptchaSiteKey:'',demo:true}
}

async function results():Promise<Results>{
  const state=loadState(),all=await videos()
  const groups={} as Results['groups']
  for(const group of ['individual','team'] as Category[]){
    const ranked=all.filter(video=>video.category===group).map((video,index)=>({...video,votes:Math.max(0,15-index)+(state.votes.some(v=>v.videoId===video.id)?1:0),rank:0})).sort((a,b)=>b.votes-a.votes||a.id-b.id)
    groups[group]=ranked.map((video,index)=>({...video,rank:index+1}))
  }
  return {published:true,live:true,generatedAt:new Date().toISOString(),activity:{state:'active',startsAt:'2026-10-12T02:00:00Z',endsAt:'2026-10-23T09:00:00Z'},groups}
}

export async function demoApi<T>(url:string,init?:RequestInit):Promise<T>{
  const method=(init?.method||'GET').toUpperCase(),payload=body(init),state=loadState()
  if(url==='/api/bootstrap')return await bootstrap() as T
  if(url==='/api/results')return await results() as T
  if(url==='/api/watch/start'&&method==='POST'){
    const sessionId=crypto.randomUUID(),videoId=Number(payload.videoId),duration=Math.max(1,Number(payload.duration)||1)
    sessions.set(sessionId,{videoId,duration,watchedSeconds:0,lastPosition:0})
    return {sessionId} as T
  }
  if(url==='/api/watch/progress'&&method==='POST'){
    const session=sessions.get(String(payload.sessionId));if(!session)throw new Error('Demo 觀看工作階段已失效，請重新開啟影片。')
    const position=Math.min(session.duration,Math.max(0,Number(payload.position)||0))
    const delta=position-session.lastPosition
    const plausible=payload.playing===true&&payload.visible===true&&Number(payload.playbackRate)>0&&Number(payload.playbackRate)<=1.25&&delta>=0&&delta<=7
    if(plausible)session.watchedSeconds=Math.min(session.duration,session.watchedSeconds+delta)
    session.lastPosition=position
    const ratio=Math.min(1,session.watchedSeconds/session.duration),existing=state.progress.find(item=>item.videoId===session.videoId)
    if(existing){existing.ratio=Math.max(existing.ratio,ratio);existing.qualified=Boolean(existing.qualified)||ratio>=.8}else state.progress.push({videoId:session.videoId,ratio,qualified:ratio>=.8})
    saveState(state);return {ratio:existing?.ratio??ratio,qualified:Boolean(existing?.qualified)||ratio>=.8} as T
  }
  if(url==='/api/votes'&&method==='POST'){
    const videoId=Number(payload.videoId),group=category(videoId)
    if(state.votes.some(v=>v.videoId===videoId))throw new Error('這支作品已投過票。')
    if(remaining(state,group)<=0)throw new Error('本組已投滿 2 票，請先取消其中一票。')
    const qualified=state.progress.some(item=>item.videoId===videoId&&(Boolean(item.qualified)||item.ratio>=.8));if(!qualified)throw new Error('觀看進度尚未達 80%。')
    const vote:Vote={id:Date.now(),videoId,category:group,status:'valid',createdAtUtc:new Date().toISOString()};state.votes.push(vote);saveState(state);return vote as T
  }
  const cancel=url.match(/^\/api\/votes\/(\d+)$/)
  if(cancel&&method==='DELETE'){state.votes=state.votes.filter(v=>v.id!==Number(cancel[1]));saveState(state);return {ok:true} as T}
  throw new Error(`Demo 尚未提供此操作：${method} ${url}`)
}
