<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { api } from './api'
import { deviceSignal, loadBootstrap } from './deviceContext'
import { displayWorkNumber } from './workNumber'
import type { Bootstrap, Video, Vote, WatchProgress } from './types'

declare global {
  interface Window { YT?:any; onYouTubeIframeAPIReady?:()=>void; grecaptcha?:any; onRecaptchaReady?:()=>void }
}

const props=defineProps<{data:Bootstrap}>()
const emit=defineEmits<{updated:[Bootstrap];resultsChanged:[]}>()
const watchDialog=ref<HTMLDialogElement>(),watchCloseButton=ref<HTMLButtonElement>(),confirmDialog=ref<HTMLDialogElement>(),playerHost=ref<HTMLElement>(),captchaBox=ref<HTMLElement>(),developmentCaptchaInput=ref<HTMLInputElement>()
const current=ref<Video|null>(null),player=ref<any>(null),playerState=ref<number|null>(null),sessionId=ref(''),timer=ref<number>(),captchaToken=ref(''),captchaId=ref<number|null>(null),captchaReloading=ref(false),busy=ref(false),message=ref(''),messageError=ref(false)
const isWatchOpen=ref(false)
const confirmTitle=ref(''),confirmMessage=ref(''),confirmText=ref('確認'),confirmTone=ref('vote')
let confirmationResolve:((answer:boolean)=>void)|null=null
let captchaLoadPromise:Promise<void>|null=null
let playerGeneration=0
let sessionInitializationGeneration:number|null=null
let initializationRetryTimer:number|undefined
let lastObservedPosition:number|null=null
let lastClientTickAt:number|null=null
const progressRequestsInFlight=new Set<number>()
const durationRetryDelayMs=500
const durationRetryLimit=20
const localProgressKey='greencare-client-watch-v1'
const memoryProgress:Record<string,StoredClientProgress>={}
let clientDuration=0
let clientWatchedSeconds=0
let clientReportedPosition=0
let lastClientPosition:number|null=null
let lastLocalSaveAt=0
let lockedScrollY=0
let previousFocus:HTMLElement|null=null
let pageStyleSnapshot:{htmlOverflow:string;bodyOverflow:string;bodyPosition:string;bodyTop:string;bodyWidth:string}|null=null

const groupName=computed(()=>current.value?.category==='team'?'團體組':'個人組')
const currentVote=computed(()=>current.value?props.data.votes.find(v=>v.videoId===current.value!.id):undefined)
const currentNumber=computed(()=>current.value?displayWorkNumber(current.value,props.data.videos):'')
const ratio=computed(()=>current.value?props.data.progress.find(p=>p.videoId===current.value!.id)?.ratio??0:0)
const qualified=computed(()=>ratio.value>=.8||Boolean(current.value&&props.data.progress.find(p=>p.videoId===current.value!.id)?.qualified))
const groupVotes=computed(()=>current.value?props.data.votes.filter(v=>v.category===current.value!.category):[])
const cancellationAllowed=computed(()=>props.data.allowVoteCancellation)
const cancellableGroupVotes=computed(()=>cancellationAllowed.value?groupVotes.value.filter(v=>v.canCancel):[])
const groupFull=computed(()=>!currentVote.value&&groupVotes.value.length>=2)
const showCaptcha=computed(()=>!currentVote.value&&!groupFull.value&&qualified.value&&props.data.activity.state==='active')
const captchaVisible=computed(()=>!props.data.recaptchaSiteKey||captchaId.value!==null)
const videosInGroup=computed(()=>props.data.videos.filter(v=>v.category===current.value?.category))
const currentIndex=computed(()=>videosInGroup.value.findIndex(v=>v.id===current.value?.id))
const canVote=computed(()=>!busy.value&&!currentVote.value&&!groupFull.value&&Boolean(current.value?.youtubeId)&&qualified.value&&props.data.activity.state==='active')
const voteButtonText=computed(()=>currentVote.value?(currentVote.value.status==='flagged'?'此票待確認':'已投票'):!current.value?.youtubeId?'影片尚未開放':!qualified.value?'尚未達投票門檻':props.data.activity.state!=='active'?'目前不在投票期間':groupFull.value?(cancellationAllowed.value?'請先取消一票':'本組已投滿 2 票'):busy.value?'處理中':`投給作品 ${currentNumber.value}`)
const replacePanelMessage=computed(()=>cancellationAllowed.value?(cancellableGroupVotes.value.length?'本組已投滿 2 票。可先取消此瀏覽器投出的票，再投其他作品：':'本組已在其他瀏覽器投滿 2 票。如需改投，請回到原投票瀏覽器取消其中一票。'):'本組已投滿 2 票，投票送出後無法取消或改投。')
const progressPercent=computed(()=>Math.min(100,Math.floor(ratio.value*100)))

function voteWork(vote:Vote){return props.data.videos.find(v=>v.id===vote.videoId)}
function workNumber(video:Video|undefined){return video?displayWorkNumber(video,props.data.videos):''}
function setMessage(text:string,error=false){message.value=text;messageError.value=error}
type StoredClientProgress={videoId:number;youtubeId:string;duration:number;watchedSeconds:number;lastPosition:number;updatedAt:string}
function storedProgress():Record<string,StoredClientProgress>{try{return {...JSON.parse(localStorage.getItem(localProgressKey)||'{}'),...memoryProgress}}catch{return {...memoryProgress}}}
function restoreClientProgress(video:Video){const saved=storedProgress()[video.id];clientDuration=saved?.youtubeId===video.youtubeId?saved.duration:0;clientWatchedSeconds=saved?.youtubeId===video.youtubeId?saved.watchedSeconds:0;clientReportedPosition=saved?.youtubeId===video.youtubeId?saved.lastPosition:0;lastClientPosition=null;if(clientDuration>0)updateDisplayedProgress()}
function saveClientProgress(force=false){if(!current.value||clientDuration<10)return;const now=Date.now();const saved={videoId:current.value.id,youtubeId:current.value.youtubeId,duration:clientDuration,watchedSeconds:clientWatchedSeconds,lastPosition:clientReportedPosition,updatedAt:new Date(now).toISOString()};memoryProgress[current.value.id]=saved;if(!force&&now-lastLocalSaveAt<3000)return;const all=storedProgress();all[current.value.id]=saved;try{localStorage.setItem(localProgressKey,JSON.stringify(all));lastLocalSaveAt=now}catch{/* Progress remains available in memory for this vote. */}}
function updateDisplayedProgress(){if(!current.value||clientDuration<=0)return;const next=Math.min(1,clientWatchedSeconds/clientDuration),existing=props.data.progress.find(p=>p.videoId===current.value!.id);if(existing){existing.ratio=Math.max(existing.ratio,next);existing.qualified=Boolean(existing.qualified)||next>=.8}else props.data.progress.push({videoId:current.value.id,ratio:next,qualified:next>=.8})}
function clientProgressPayload(){if(!current.value||clientDuration<10)return null;return {videoId:current.value.id,youtubeId:current.value.youtubeId,duration:clientDuration,watchedSeconds:Math.min(clientDuration,clientWatchedSeconds),lastPosition:Math.min(clientDuration,Math.max(0,clientReportedPosition))}}
function syncUrl(id?:number){const url=new URL(location.href);id?url.searchParams.set('work',String(id)):url.searchParams.delete('work');url.hash=id?'works':'';history.replaceState(null,'',url)}

async function ytReady(){
  if(window.YT?.Player)return
  await new Promise<void>((resolve,reject)=>{const old=window.onYouTubeIframeAPIReady;window.onYouTubeIframeAPIReady=()=>{old?.();resolve()};if(!document.querySelector('script[data-youtube-api]')){const script=document.createElement('script');script.src='https://www.youtube.com/iframe_api';script.dataset.youtubeApi='true';script.onerror=()=>reject(new Error('YouTube 播放器載入失敗。'));document.head.appendChild(script)}})
}
async function createPlayer(video:Video){
  if(!video.youtubeId||!playerHost.value)return
  const generation=playerGeneration
  try{await ytReady();if(current.value?.id!==video.id||generation!==playerGeneration)return;player.value=new window.YT.Player(playerHost.value,{videoId:video.youtubeId,playerVars:{rel:0,playsinline:1},events:{onReady:()=>void onPlayerReady(video.id,generation),onStateChange:onPlayerState}})}catch(error){setMessage(error instanceof Error?error.message:'YouTube 播放器載入失敗。',true)}
}
function delay(milliseconds:number){return new Promise<void>(resolve=>window.setTimeout(resolve,milliseconds))}
async function waitForDuration(videoId:number,generation:number){
  for(let attempt=0;attempt<durationRetryLimit;attempt++){
    if(current.value?.id!==videoId||generation!==playerGeneration)return null
    const duration=Number(player.value?.getDuration?.())
    if(Number.isFinite(duration)&&duration>=10&&duration<=7200)return duration
    await delay(durationRetryDelayMs)
  }
  return null
}
async function onPlayerReady(videoId:number,generation:number){
  if(sessionId.value||sessionInitializationGeneration===generation)return
  sessionInitializationGeneration=generation
  setMessage('正在初始化觀看紀錄…')
  try{
    const duration=await waitForDuration(videoId,generation)
    if(current.value?.id!==videoId||generation!==playerGeneration)return
    if(duration===null){setMessage('影片仍在載入，播放後會自動繼續嘗試。',true);scheduleInitializationRetry(videoId,generation);return}
    clearInitializationRetry()
    clientDuration=duration
    clientWatchedSeconds=Math.max(clientWatchedSeconds,progressForCurrent()*duration)
    setMessage('')
    startProgressPolling()
    try{
      const result=await api<{sessionId:string}>('/api/watch/start',{method:'POST',body:JSON.stringify({videoId,duration})})
      if(current.value?.id!==videoId||generation!==playerGeneration)return
      sessionId.value=result.sessionId
    }catch(error){
      if(current.value?.id===videoId&&generation===playerGeneration)setMessage('觀看紀錄暫時無法同步，進度仍會保存在此瀏覽器。',true)
    }
  }catch(error){setMessage(error instanceof Error?error.message:'播放器初始化失敗。',true)}finally{
    if(sessionInitializationGeneration===generation)sessionInitializationGeneration=null
  }
}
function clearInitializationRetry(){if(initializationRetryTimer)window.clearTimeout(initializationRetryTimer);initializationRetryTimer=undefined}
function scheduleInitializationRetry(videoId:number,generation:number){clearInitializationRetry();initializationRetryTimer=window.setTimeout(()=>{initializationRetryTimer=undefined;if(current.value?.id===videoId&&generation===playerGeneration&&clientDuration<10)void onPlayerReady(videoId,generation)},1000)}
function onPlayerState(event:{data:number}){const previous=playerState.value;playerState.value=event.data;if(event.data===window.YT.PlayerState.PLAYING){if(clientDuration<10&&current.value)void onPlayerReady(current.value.id,playerGeneration);else startProgressPolling()}else if(previous===window.YT.PlayerState.PLAYING)void syncClientProgress()}
function validPosition(){const position=Number(player.value?.getCurrentTime?.());return Number.isFinite(position)&&position>=0?position:null}
function progressForCurrent(){return current.value?props.data.progress.find(item=>item.videoId===current.value!.id)?.ratio??0:0}
function startProgressPolling(){
  clearTimer()
  lastObservedPosition=validPosition()
  lastClientPosition=lastObservedPosition
  lastClientTickAt=performance.now()
  timer.value=window.setInterval(()=>void pollProgress(),1000)
}
async function pollProgress(){
  if(document.hidden)return
  const now=performance.now()
  const elapsedSeconds=Math.min(10,Math.max(0,(now-(lastClientTickAt??now))/1000))
  lastClientTickAt=now
  const position=validPosition()
  if(position===null)return
  const advanced=lastObservedPosition!==null&&position>lastObservedPosition+.1
  lastObservedPosition=position
  const reportedPlaying=player.value?.getPlayerState?.()===window.YT?.PlayerState?.PLAYING
  const rate=Number(player.value?.getPlaybackRate?.())
  if((reportedPlaying||advanced)&&Number.isFinite(rate)&&rate>0&&rate<=1.25){
    if(lastClientPosition!==null){const delta=position-lastClientPosition;const plausible=delta>=0&&delta<=elapsedSeconds*1.6+1;if(plausible){clientWatchedSeconds=Math.min(clientDuration,clientWatchedSeconds+Math.min(elapsedSeconds,delta+.5));updateDisplayedProgress();saveClientProgress()}}
    clientReportedPosition=position
    lastClientPosition=position
  }else{clientReportedPosition=position;lastClientPosition=position}
}
async function syncClientProgress(){
  const video=current.value
  if(!video||progressRequestsInFlight.has(video.id))return
  const payload=clientProgressPayload();if(!payload)return
  progressRequestsInFlight.add(video.id)
  try{
    saveClientProgress(true)
    const update=await api<{ratio:number;qualified:boolean}>('/api/watch/client-sync',{method:'POST',body:JSON.stringify(payload)})
    const existing=props.data.progress.find(p=>p.videoId===video.id)
    if(existing){existing.ratio=Math.max(existing.ratio,update.ratio);existing.qualified=Boolean(existing.qualified)||update.qualified}else props.data.progress.push({videoId:video.id,ratio:update.ratio,qualified:update.qualified})
    if(current.value?.id===video.id&&update.qualified&&!captchaToken.value){await nextTick();await setupCaptcha()}
  }catch(error){
    const text=error instanceof Error?error.message:'觀看進度更新失敗。'
    setMessage(text,true)
  }finally{progressRequestsInFlight.delete(video.id)}
}
function clearTimer(){if(timer.value)window.clearInterval(timer.value);timer.value=undefined;lastObservedPosition=null;lastClientTickAt=null}
function resetCaptcha(){captchaToken.value='';if(captchaId.value!==null)window.grecaptcha?.enterprise?.reset(captchaId.value);if(developmentCaptchaInput.value)developmentCaptchaInput.value.checked=false}

function lockPageScroll(){
  if(pageStyleSnapshot)return
  lockedScrollY=window.scrollY
  pageStyleSnapshot={htmlOverflow:document.documentElement.style.overflow,bodyOverflow:document.body.style.overflow,bodyPosition:document.body.style.position,bodyTop:document.body.style.top,bodyWidth:document.body.style.width}
  document.documentElement.style.overflow='hidden'
  document.body.style.overflow='hidden'
  document.body.style.position='fixed'
  document.body.style.top=`-${lockedScrollY}px`
  document.body.style.width='100%'
}
function unlockPageScroll(){
  if(!pageStyleSnapshot)return
  const snapshot=pageStyleSnapshot
  pageStyleSnapshot=null
  document.documentElement.style.overflow=snapshot.htmlOverflow
  document.body.style.overflow=snapshot.bodyOverflow
  document.body.style.position=snapshot.bodyPosition
  document.body.style.top=snapshot.bodyTop
  document.body.style.width=snapshot.bodyWidth
  window.scrollTo({top:lockedScrollY,left:0,behavior:'instant'})
}
function trapWatchFocus(event:KeyboardEvent){
  if(event.key!=='Tab'||!watchDialog.value)return
  const focusable=Array.from(watchDialog.value.querySelectorAll<HTMLElement>('button:not([disabled]), [href], input:not([disabled]), iframe, [tabindex]:not([tabindex="-1"])')).filter(element=>!element.hasAttribute('hidden')&&element.getClientRects().length>0)
  if(!focusable.length)return
  const first=focusable[0],last=focusable[focusable.length-1]
  if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus()}
  else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus()}
}
function watchKeydown(event:KeyboardEvent){if(event.key==='Escape'&&isWatchOpen.value&&!confirmDialog.value?.open){event.preventDefault();close()}}

  async function open(videoId:number){const video=props.data.videos.find(v=>v.id===videoId);if(!video)return;playerGeneration++;sessionInitializationGeneration=null;clearInitializationRetry();clearTimer();player.value?.destroy?.();resetCaptcha();current.value=video;restoreClientProgress(video);sessionId.value='';playerState.value=null;message.value='';syncUrl(video.id);const opening=!watchDialog.value?.open;if(opening){previousFocus=document.activeElement instanceof HTMLElement?document.activeElement:null;lockPageScroll();isWatchOpen.value=true;watchDialog.value?.show()}await nextTick();if(opening)watchCloseButton.value?.focus({preventScroll:true});if(props.data.recaptchaSiteKey)void loadCaptchaScript().catch(()=>{/* setupCaptcha will show an error if the user becomes eligible. */});if(showCaptcha.value)await setupCaptcha();void createPlayer(video)}
async function navigate(offset:number){const target=videosInGroup.value[currentIndex.value+offset];if(!target)return;await syncClientProgress();await open(target.id)}
function close(){playerGeneration++;sessionInitializationGeneration=null;clearInitializationRetry();clearTimer();void syncClientProgress();player.value?.stopVideo?.();player.value?.destroy?.();player.value=null;watchDialog.value?.close();isWatchOpen.value=false;unlockPageScroll();syncUrl();const target=previousFocus;previousFocus=null;window.requestAnimationFrame(()=>target?.focus({preventScroll:true}))}

  async function loadCaptchaScript(){
    if(!props.data.recaptchaSiteKey||window.grecaptcha?.enterprise)return
  if(!window.grecaptcha?.enterprise&&!captchaLoadPromise){
    captchaLoadPromise=new Promise<void>((resolve,reject)=>{
      const timeout=window.setTimeout(()=>reject(new Error('驗證元件載入逾時，請重新整理後再試。')),15000)
      window.onRecaptchaReady=()=>{window.clearTimeout(timeout);resolve()}
      const script=document.createElement('script')
      script.src='https://www.google.com/recaptcha/enterprise.js?onload=onRecaptchaReady&render=explicit'
      script.dataset.recaptchaApi='true'
      script.async=true
      script.defer=true
      script.onerror=()=>{window.clearTimeout(timeout);script.remove();reject(new Error('驗證元件載入失敗。'))}
      document.head.appendChild(script)
    })
  }
    try{await captchaLoadPromise}catch(error){captchaLoadPromise=null;throw error}
  }
  async function setupCaptcha(){
    captchaToken.value=''
    if(!props.data.recaptchaSiteKey)return
    if(captchaId.value!==null){window.grecaptcha?.enterprise?.reset(captchaId.value);return}
    try{await loadCaptchaScript()}catch(error){setMessage(error instanceof Error?error.message:'驗證元件載入失敗。',true);return}
    if(window.grecaptcha?.enterprise&&captchaBox.value&&captchaId.value===null)captchaId.value=window.grecaptcha.enterprise.render(captchaBox.value,{sitekey:props.data.recaptchaSiteKey,action:'vote',callback:(token:string)=>captchaToken.value=token,'expired-callback':()=>captchaToken.value='','error-callback':()=>setMessage('驗證暫時無法使用，請點右側的刷新圖示再試一次。',true)})
}
  async function reloadCaptcha(){
    if(captchaReloading.value)return
    captchaReloading.value=true
    captchaToken.value=''
    const payload=clientProgressPayload()
    saveClientProgress(true)
    if(payload)navigator.sendBeacon?.('/api/watch/client-sync',new Blob([JSON.stringify(payload)],{type:'application/json'}))
    await delay(300)
    window.location.reload()
  }
watch(showCaptcha,async visible=>{if(visible){await nextTick();await setupCaptcha()}})
function developmentCaptcha(checked:boolean){captchaToken.value=checked?'development-pass':''}
function askConfirmation(title:string,body:string,accept:string,tone='vote'){confirmTitle.value=title;confirmMessage.value=body;confirmText.value=accept;confirmTone.value=tone;confirmDialog.value?.showModal();return new Promise<boolean>(resolve=>confirmationResolve=resolve)}
function finishConfirmation(answer:boolean){confirmDialog.value?.close();const resolve=confirmationResolve;confirmationResolve=null;resolve?.(answer)}

async function reload(){const data=await loadBootstrap();emit('updated',data);emit('resultsChanged')}
async function submitVote(){
  if(groupFull.value){setMessage(cancellationAllowed.value?'本組已投滿 2 票，請先前往已投票的作品取消其中一票。':'本組已投滿 2 票，投票送出後無法取消或改投。',true);return}
  if(!captchaToken.value){setMessage('請先完成「我不是機器人」驗證。',true);return}
  const text=`投給「作品 ${currentNumber.value}－${current.value!.title}」。`
  if(!await askConfirmation('確認投票',text,'確認投票'))return
  busy.value=true
  try{const local=clientProgressPayload();await api('/api/votes',{method:'POST',body:JSON.stringify({videoId:current.value!.id,recaptchaToken:captchaToken.value,deviceSignal:deviceSignal(),watchProgress:local&&local.watchedSeconds/local.duration>=.8?local:null})});setMessage('投票成功，謝謝你的參與。');await reload()}catch(error){setMessage(error instanceof Error?error.message:'投票失敗。',true)}finally{busy.value=false;resetCaptcha()}
}
async function cancelVote(){if(!currentVote.value?.canCancel)return;if(!await askConfirmation('取消投票',`取消投給「作品 ${currentNumber.value}－${current.value!.title}」的票，該組將立即釋放一票額度。`,'確認取消','cancel'))return;busy.value=true;try{await api(`/api/votes/${currentVote.value.id}`,{method:'DELETE'});setMessage('已取消投票。');await reload()}catch(error){setMessage(error instanceof Error?error.message:'取消投票失敗。',true)}finally{busy.value=false}}
async function visibilityChanged(){
  clearTimer()
  await syncClientProgress()
  if(!document.hidden&&current.value&&clientDuration>=10)startProgressPolling()
}
function pageHiding(){const payload=clientProgressPayload();if(!payload)return;saveClientProgress(true);navigator.sendBeacon?.('/api/watch/client-sync',new Blob([JSON.stringify(payload)],{type:'application/json'}))}
document.addEventListener('visibilitychange',visibilityChanged)
window.addEventListener('pagehide',pageHiding)
window.addEventListener('keydown',watchKeydown)
onBeforeUnmount(()=>{playerGeneration++;document.removeEventListener('visibilitychange',visibilityChanged);window.removeEventListener('pagehide',pageHiding);window.removeEventListener('keydown',watchKeydown);clearInitializationRetry();clearTimer();player.value?.destroy?.();unlockPageScroll()})
defineExpose({open})
</script>

<template>
  <dialog ref="confirmDialog" class="confirm-dialog" :data-tone="confirmTone" aria-labelledby="confirmTitle" aria-describedby="confirmMessage" @cancel.prevent="finishConfirmation(false)" @click.self="finishConfirmation(false)">
    <div class="confirm-mark" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 7v6M12 17h.01"/></svg></div><div class="confirm-copy"><p class="confirm-eyebrow">投票確認</p><h2 id="confirmTitle">{{confirmTitle}}</h2><p id="confirmMessage">{{confirmMessage}}</p></div><div class="confirm-actions"><button class="confirm-secondary" type="button" @click="finishConfirmation(false)">返回</button><button class="confirm-primary" type="button" @click="finishConfirmation(true)">{{confirmText}}</button></div>
  </dialog>
  <div v-if="isWatchOpen" class="watch-backdrop" aria-hidden="true" @click="close"></div>
  <dialog ref="watchDialog" class="watch-dialog" :data-category="current?.category" aria-modal="true" aria-label="作品觀看與投票" @cancel.prevent="close" @keydown="trapWatchFocus">
    <button ref="watchCloseButton" class="close" type="button" aria-label="關閉播放器" @click="close"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg></button>
    <div class="player-wrap"><div ref="playerHost"></div><div v-if="current&&!current.youtubeId" class="unavailable">影片尚未設定，請稍後再來。</div></div>
    <div class="watch-info">
      <div class="watch-heading"><p class="eyebrow">{{groupName}} {{currentNumber}}</p><h2>{{current?.title}}</h2><p class="watch-team">{{current?.team}}</p></div>
      <div class="progress-block"><div class="progress-label"><span>有效觀看進度</span><strong>{{progressPercent}}%</strong></div><div class="progress"><span :style="{width:`${progressPercent}%`}"></span></div><p>觀看達 80% 後即可投票。快轉及背景播放不列入進度。</p></div>
      <div v-if="groupFull" class="replace-panel"><strong>{{replacePanelMessage}}</strong><div v-if="cancellationAllowed&&cancellableGroupVotes.length"><button v-for="vote in cancellableGroupVotes" :key="vote.id" type="button" @click="open(vote.videoId)"><span>作品 {{workNumber(voteWork(vote))}}・{{voteWork(vote)?.title}}</span><em>前往查看</em></button></div></div>
        <div v-show="showCaptcha" class="captcha-support"><div class="captcha-row"><div ref="captchaBox" class="recaptcha-box" :class="{'captcha-visible':captchaVisible}"><label v-if="!data.recaptchaSiteKey" class="demo-captcha"><input ref="developmentCaptchaInput" type="checkbox" @change="developmentCaptcha(($event.target as HTMLInputElement).checked)"> <span><strong>{{data.demo?'展示版驗證':'本機開發驗證'}}</strong><small>正式環境將使用 reCAPTCHA</small></span></label></div><button class="captcha-refresh" type="button" :disabled="captchaReloading" aria-label="重新整理頁面" title="重新整理頁面" @click="reloadCaptcha"><svg :class="{'is-spinning':captchaReloading}" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12a9 9 0 1 1-2.64-6.36L21 8M21 3v5h-5"/></svg></button></div><p class="captcha-help">勾選沒反應？請點右側刷新圖示重新整理，或改用手機預設瀏覽器開啟。</p></div>
      <button class="vote-button" type="button" :disabled="!canVote" @click="submitVote">{{voteButtonText}}</button><button v-if="cancellationAllowed&&currentVote?.canCancel&&data.activity.state==='active'" class="cancel-vote-button" type="button" :disabled="busy" @click="cancelVote">取消這一票</button>
      <p class="message" :class="messageError?'error':'success'" role="status">{{message}}</p>
      <nav class="video-pagination" aria-label="切換參賽影片"><button type="button" :disabled="currentIndex<=0" @click="navigate(-1)"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 5-7 7 7 7"/></svg><span>上一部</span></button><button type="button" :disabled="currentIndex<0||currentIndex>=videosInGroup.length-1" @click="navigate(1)"><span>下一部</span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 5 7 7-7 7"/></svg></button></nav>
    </div>
  </dialog>
</template>
